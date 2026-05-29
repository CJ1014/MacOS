/* kernel.c — AquaOS: a from-scratch 32-bit kernel that boots via Multiboot2
 * and paints a macOS Sonoma-style desktop directly into the linear
 * framebuffer GRUB hands us. No OS base, no libc — just the metal.
 *
 *   - vertical gradient "wallpaper"
 *   - translucent top menu bar with an Apple logo, menu titles, and a
 *     LIVE clock driven by the CMOS real-time clock
 *   - a frosted dock with rounded, gradient app icons
 */

#include "font8x8.h"

typedef unsigned char  u8;
typedef unsigned short u16;
typedef unsigned int   u32;
typedef unsigned long long u64;
typedef int            i32;

/* ---- port I/O (for reading the CMOS RTC) ---- */
static inline u8 inb(u16 port) {
    u8 v; __asm__ volatile ("inb %1, %0" : "=a"(v) : "Nd"(port));
    return v;
}
static inline void outb(u16 port, u8 v) {
    __asm__ volatile ("outb %0, %1" : : "a"(v), "Nd"(port));
}

/* ---- framebuffer state, filled in from the Multiboot2 info ---- */
static volatile u8 *fb;     /* base address                       */
static u32 fb_pitch;        /* bytes per scanline                 */
static u32 fb_w, fb_h;      /* dimensions in pixels               */
static u32 fb_bytespp;      /* bytes per pixel (bpp/8)            */
static u32 r_pos, g_pos, b_pos;  /* channel bit positions          */

#define MENUBAR_H 26
#define RGB(r,g,b) (((u32)(r)<<16)|((u32)(g)<<8)|(u32)(b))

/* ---- low-level pixel access ----
 * We don't assume a fixed pixel layout: the channel bit-positions and the
 * bytes-per-pixel are taken from the framebuffer info GRUB gives us, so the
 * same code works whether the firmware hands us RGB, BGR, 24-bpp, or 32-bpp.
 * Colors are always passed around as 0x00RRGGBB and (de)coded here. */
static inline u32 encode(u32 color) {
    u32 r=(color>>16)&0xFF, g=(color>>8)&0xFF, b=color&0xFF;
    return (r<<r_pos) | (g<<g_pos) | (b<<b_pos);
}
static inline void put(u32 x, u32 y, u32 color) {
    if (x >= fb_w || y >= fb_h) return;
    u32 v = encode(color);
    volatile u8 *p = fb + y * fb_pitch + x * fb_bytespp;
    p[0] =  v        & 0xFF;
    if (fb_bytespp > 1) p[1] = (v >> 8)  & 0xFF;
    if (fb_bytespp > 2) p[2] = (v >> 16) & 0xFF;
    if (fb_bytespp > 3) p[3] = (v >> 24) & 0xFF;
}
static inline u32 get(u32 x, u32 y) {
    if (x >= fb_w || y >= fb_h) return 0;
    volatile u8 *p = fb + y * fb_pitch + x * fb_bytespp;
    u32 v = p[0];
    if (fb_bytespp > 1) v |= (u32)p[1] << 8;
    if (fb_bytespp > 2) v |= (u32)p[2] << 16;
    if (fb_bytespp > 3) v |= (u32)p[3] << 24;
    return RGB((v>>r_pos)&0xFF, (v>>g_pos)&0xFF, (v>>b_pos)&0xFF);
}

/* alpha-blend src over dst, a in 0..255 */
static inline u32 blend(u32 src, u32 dst, u32 a) {
    u32 sr=(src>>16)&0xFF, sg=(src>>8)&0xFF, sb=src&0xFF;
    u32 dr=(dst>>16)&0xFF, dg=(dst>>8)&0xFF, db=dst&0xFF;
    u32 r=(sr*a + dr*(255-a))/255;
    u32 g=(sg*a + dg*(255-a))/255;
    u32 b=(sb*a + db*(255-a))/255;
    return RGB(r,g,b);
}

static void fill_rect(i32 x0, i32 y0, i32 w, i32 h, u32 color) {
    for (i32 y=y0; y<y0+h; y++)
        for (i32 x=x0; x<x0+w; x++)
            if (x>=0 && y>=0) put(x,y,color);
}

/* translucent rectangle (blends over whatever is already there) */
static void blend_rect(i32 x0, i32 y0, i32 w, i32 h, u32 color, u32 a) {
    for (i32 y=y0; y<y0+h; y++)
        for (i32 x=x0; x<x0+w; x++)
            if (x>=0 && y>=0 && (u32)x<fb_w && (u32)y<fb_h)
                put(x,y, blend(color, get(x,y), a));
}

/* filled rounded rectangle, alpha-blended */
static void rounded_rect(i32 x0, i32 y0, i32 w, i32 h, i32 r, u32 color, u32 a) {
    for (i32 y=0; y<h; y++) {
        for (i32 x=0; x<w; x++) {
            i32 dx=-1, dy=-1;
            if (x < r && y < r)         { dx=r-1-x; dy=r-1-y; }
            else if (x >= w-r && y < r) { dx=x-(w-r); dy=r-1-y; }
            else if (x < r && y >= h-r) { dx=r-1-x; dy=y-(h-r); }
            else if (x >= w-r && y >= h-r){ dx=x-(w-r); dy=y-(h-r); }
            if (dx>=0 && dx*dx+dy*dy > r*r) continue;   /* outside corner */
            i32 px=x0+x, py=y0+y;
            if (px>=0 && py>=0 && (u32)px<fb_w && (u32)py<fb_h)
                put(px,py, blend(color, get(px,py), a));
        }
    }
}

/* ---- text: 8x8 font, integer-scaled ---- */
static void draw_char(i32 x, i32 y, char c, u32 color, i32 scale) {
    if ((u8)c >= 128) c = '?';
    const u8 *g = font8x8_basic[(u8)c];
    for (i32 row=0; row<8; row++)
        for (i32 col=0; col<8; col++)
            if (g[row] & (1<<col))
                fill_rect(x+col*scale, y+row*scale, scale, scale, color);
}
static void draw_text(i32 x, i32 y, const char *s, u32 color, i32 scale) {
    for (; *s; s++) { draw_char(x,y,*s,color,scale); x += 8*scale; }
}
static i32 text_w(const char *s, i32 scale) {
    i32 n=0; while (*s++) n++; return n*8*scale;
}

/* ---- Apple logo, hand-drawn as a glyph map ('#'=ink) ---- */
static const char *apple_logo[] = {
    "...........#....",
    "..........#.....",
    ".........##.....",
    "....####.##.....",
    "..#########.....",
    ".###############",
    "################",
    "################",
    "################",
    "################",
    ".##############.",
    ".##############.",
    "..############..",
    "...##########...",
    "....########....",
    ".....#....#.....",
};
static void draw_apple(i32 x, i32 y, u32 color, i32 scale) {
    for (i32 row=0; row<16; row++)
        for (i32 col=0; col<16; col++)
            if (apple_logo[row][col]=='#')
                fill_rect(x+col*scale, y+row*scale, scale, scale, color);
}

/* ---- wallpaper: smooth vertical gradient (Sonoma-ish blue→violet) ---- */
static void draw_wallpaper(void) {
    u32 r0=30,  g0=58,  b0=138;   /* top    */
    u32 r1=124, g1=58,  b1=200;   /* bottom */
    for (u32 y=0; y<fb_h; y++) {
        u32 r=r0+(r1-r0)*y/fb_h;
        u32 g=g0+(g1-g0)*y/fb_h;
        u32 b=b0+(b1-b0)*y/fb_h;
        u32 c=RGB(r,g,b);
        for (u32 x=0; x<fb_w; x++) put(x,y,c);
    }
}

/* ---- dock with rounded gradient icons ---- */
static const u32 icon_colors[] = {
    RGB(0,122,255), RGB(52,199,89),  RGB(255,149,0),  RGB(255,59,48),
    RGB(175,82,222),RGB(255,204,0),  RGB(90,200,250), RGB(88,86,214),
};
static void draw_dock(void) {
    const i32 n = sizeof(icon_colors)/sizeof(icon_colors[0]);
    const i32 isz = 48, gap = 12, pad = 16;
    i32 dock_w = n*isz + (n-1)*gap + 2*pad;
    i32 dock_h = isz + 2*pad/2 + 8;
    i32 dx = (fb_w - dock_w)/2;
    i32 dy = fb_h - dock_h - 14;

    /* frosted glass panel */
    rounded_rect(dx, dy, dock_w, dock_h, 22, RGB(245,245,250), 150);
    rounded_rect(dx, dy, dock_w, dock_h, 22, RGB(255,255,255), 30);

    i32 iy = dy + (dock_h - isz)/2;
    for (i32 i=0; i<n; i++) {
        i32 ix = dx + pad + i*(isz+gap);
        /* vertical light->base gradient for a glossy look */
        u32 base = icon_colors[i];
        for (i32 yy=0; yy<isz; yy++) {
            u32 top=blend(RGB(255,255,255), base, 70);
            u32 col=blend(top, base, (yy*255)/isz);
            for (i32 xx=0; xx<isz; xx++) {
                /* clip to rounded square */
                i32 r=12, dxx=-1, dyy=-1;
                if (xx<r&&yy<r){dxx=r-1-xx;dyy=r-1-yy;}
                else if(xx>=isz-r&&yy<r){dxx=xx-(isz-r);dyy=r-1-yy;}
                else if(xx<r&&yy>=isz-r){dxx=r-1-xx;dyy=yy-(isz-r);}
                else if(xx>=isz-r&&yy>=isz-r){dxx=xx-(isz-r);dyy=yy-(isz-r);}
                if (dxx>=0 && dxx*dxx+dyy*dyy>r*r) continue;
                put(ix+xx, iy+yy, col);
            }
        }
    }
}

/* ---- CMOS real-time clock ---- */
static u8 cmos(u8 reg){ outb(0x70,reg); return inb(0x71); }
static u8 bcd2bin(u8 v){ return (v&0x0F)+((v>>4)*10); }
static void read_clock(u8 *hh, u8 *mm, u8 *ss) {
    while (cmos(0x0A) & 0x80) ;          /* wait: no update in progress */
    u8 s=cmos(0x00), m=cmos(0x02), h=cmos(0x04), b=cmos(0x0B);
    if (!(b & 0x04)) { s=bcd2bin(s); m=bcd2bin(m); h=bcd2bin(h&0x7F); }
    *ss=s; *mm=m; *hh=h;
}

/* ---- menu bar (drawn once); returns x of the clock field ---- */
static u32 bar_color;
static i32 clock_x;
static void draw_menubar(void) {
    /* opaque-looking light bar (blend white heavily over the top gradient) */
    bar_color = blend(RGB(255,255,255), get(0,2), 205);
    fill_rect(0,0,fb_w,MENUBAR_H,bar_color);
    blend_rect(0,MENUBAR_H-1,fb_w,1, RGB(0,0,0), 30);   /* hairline */

    u32 ink = RGB(30,30,35);
    draw_apple(10, 5, ink, 1);
    i32 x = 34;
    const char *menus[] = {"Finder","File","Edit","View","Go","Window","Help"};
    for (int i=0;i<7;i++){
        int scale=1, bold=(i==0);
        draw_text(x, 9, menus[i], ink, scale);
        if (bold) draw_text(x+1, 9, menus[i], ink, scale); /* fake-bold Finder */
        x += text_w(menus[i],scale) + 18;
    }
    clock_x = fb_w - text_w("00:00:00", 1) - 14;
}

static void itoa2(u8 v, char *out){ out[0]='0'+(v/10)%10; out[1]='0'+v%10; }
static void draw_clock(void) {
    u8 h,m,s; read_clock(&h,&m,&s);
    char buf[9]; itoa2(h,buf); buf[2]=':'; itoa2(m,buf+3); buf[5]=':';
    itoa2(s,buf+6); buf[8]=0;
    fill_rect(clock_x-2, 6, text_w("00:00:00",1)+4, 12, bar_color);
    draw_text(clock_x, 9, buf, RGB(30,30,35), 1);
}

/* ---- Multiboot2 framebuffer discovery ----
 * Tag layout (type 8):
 *   8:addr(u64) 16:pitch 20:width 24:height 28:bpp(u8) 29:fb_type(u8)
 *   for direct-RGB (fb_type==1) the color_info starts at 32:
 *   32:red_pos 33:red_size 34:green_pos 35:green_size 36:blue_pos 37:blue_size
 */
#define MB2_TAG_FRAMEBUFFER 8
#define FB_TYPE_RGB 1
static int init_framebuffer(u32 magic, u32 mbi) {
    if (magic != 0x36d76289) return 0;       /* not loaded by Multiboot2 */
    u8 *p = (u8 *)mbi + 8;                    /* skip total_size + reserved */
    for (;;) {
        u32 type = *(u32 *)p;
        u32 size = *(u32 *)(p+4);
        if (type == 0) break;                 /* end tag */
        if (type == MB2_TAG_FRAMEBUFFER) {
            u32 bpp     = *(u8 *)(p+28);
            u32 fb_type = *(u8 *)(p+29);
            /* Only a direct-color (RGB) graphics framebuffer is usable.
             * If GRUB left us in text mode (fb_type==2) or a palette mode,
             * bail out rather than scribbling garbage onto the screen. */
            if (fb_type != FB_TYPE_RGB) return 0;
            if (bpp != 24 && bpp != 32) return 0;   /* 8-bit channels only */
            fb        = (volatile u8 *)(u32)(*(u64 *)(p+8));
            fb_pitch  = *(u32 *)(p+16);
            fb_w      = *(u32 *)(p+20);
            fb_h      = *(u32 *)(p+24);
            fb_bytespp= bpp / 8;
            r_pos     = *(u8 *)(p+32);
            g_pos     = *(u8 *)(p+34);
            b_pos     = *(u8 *)(p+36);
            return 1;
        }
        p += (size + 7) & ~7u;                /* tags are 8-byte aligned */
    }
    return 0;
}

void kmain(u32 magic, u32 mbi) {
    if (!init_framebuffer(magic, mbi)) {
        for (;;) __asm__ volatile ("hlt");    /* no usable framebuffer */
    }

    draw_wallpaper();
    draw_dock();
    draw_menubar();

    /* live clock: redraw only when the second changes */
    u8 last = 0xFF;
    for (;;) {
        u8 h,m,s; read_clock(&h,&m,&s);
        if (s != last) { draw_clock(); last = s; }
        for (volatile u32 i=0;i<200000;i++) ; /* gentle poll delay */
    }
}

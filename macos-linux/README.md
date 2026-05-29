# macOS-style Ubuntu live ISO (the "use a base" build)

A bootable **live ISO** that boots straight into a **macOS Sonoma-style
desktop** in VirtualBox. Unlike the from-scratch `AquaOS` in this repo's root,
this one is built on a real Ubuntu base, so it's a fully working desktop
(file manager, terminal, networking, settings) dressed up to look and feel
like macOS:

- top **menu bar** panel (app menu on the left, status icons + clock on the right)
- a **Plank dock** at the bottom with zoom-on-hover
- **WhiteSur** GTK theme + icons (macOS Big Sur/Sonoma styling)
- centered window titles with traffic-light-style controls
- a Sonoma-style **wallpaper**
- **Inter** font as a San-Francisco stand-in

> This is **not** Apple macOS and ships none of Apple's software — it's an
> Ubuntu live system themed to resemble macOS. macOS is proprietary and
> licensed only for Apple hardware.

## Build it (on an Ubuntu host)

```bash
sudo apt-get install live-build debootstrap squashfs-tools xorriso
cd macos-linux
sudo ./build.sh          # produces live-image-amd64.hybrid.iso (~1.2 GB)
```

`RELEASE=noble` is used by default (match your host's Ubuntu codename).
Run `sudo ./build.sh clean` to reset between builds.

## Run it in VirtualBox

1. **New** → Type: **Linux**, Version: **Ubuntu (64-bit)**.
2. Memory: **2048 MB+** (it's a full graphical desktop). 1 CPU is fine.
3. No virtual hard disk needed — it boots live from the ISO.
4. **Settings → Storage** → attach `live-image-amd64.hybrid.iso` to the optical drive.
5. **Settings → Display** → Graphics Controller **VMSVGA**, Video Memory **128 MB**.
6. Start. It auto-logs in and lands on the macOS-style desktop.

## How it's put together

| Path | Purpose |
|------|---------|
| `build.sh` | Runs `lb config` + `lb build`. |
| `config/package-lists/desktop.list.chroot` | Packages: Xorg, XFCE, Plank, Picom, fonts, theme build deps. |
| `config/hooks/0100-macos-theme.chroot` | Downloads + installs WhiteSur theme, icons, and wallpaper into the image. |
| `config/includes.chroot/etc/skel/.config/...` | Default XFCE settings: top panel, WhiteSur theme, centered titlebars, dock + compositor autostart, wallpaper. |
| `config/includes.chroot/etc/systemd/.../getty@tty1...` | Auto-login the live user and `startx` into the desktop. |

## Customizing

- **Theme variant:** edit the `install.sh` flags in the hook (e.g. `-c Dark`,
  `-t purple`) to change accent/colors.
- **Dock contents:** Plank shows running apps; pin more by right-clicking them
  in the dock, or edit `config/includes.chroot/etc/skel/.config/plank/...`.
- **Wallpaper:** drop your own image at
  `/usr/share/backgrounds/macos/sonoma.jpg` via the hook.

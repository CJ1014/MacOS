#!/bin/sh
# Runtime tweaks to lock in the macOS look once the XFCE session is up.
# Done at session start (not just via skel XML) so it's robust to the actual
# monitor connector name and to xfsettingsd not picking up the skel files.
IMG=/usr/share/backgrounds/macos/sonoma.jpg

# give xfdesktop/xfsettingsd a moment to come up
sleep 3

# --- GTK / window-manager / icon theme ---
xfconf-query -c xsettings -p /Net/ThemeName     -s "WhiteSur-Light-blue"
xfconf-query -c xsettings -p /Net/IconThemeName -s "WhiteSur"
xfconf-query -c xfwm4     -p /general/theme     -s "WhiteSur-Light-blue"

# --- wallpaper on every monitor/workspace xfdesktop knows about ---
if [ -f "$IMG" ]; then
    xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E '/last-image$' | while read -r p; do
        xfconf-query -c xfce4-desktop -p "$p" -s "$IMG"
    done
    # also seed common monitor names in case none exist yet
    for m in monitorVirtual-1 monitorVirtual1 monitor0 monitordefault monitorscreen; do
        base="/backdrop/screen0/$m/workspace0"
        xfconf-query -c xfce4-desktop -p "$base/last-image"  -n -t string -s "$IMG" 2>/dev/null
        xfconf-query -c xfce4-desktop -p "$base/image-style" -n -t int    -s 5      2>/dev/null
    done
    xfdesktop --reload 2>/dev/null
fi

# make sure the dock and compositor are running
pgrep -x picom >/dev/null || picom -b 2>/dev/null
pgrep -x plank >/dev/null || (plank &) 2>/dev/null

#!/bin/sh
# Runtime tweaks to lock in the macOS look once the XFCE session is up.
# Logs to ~/macos-setup.log and (best effort) the serial port for debugging.
IMG=/usr/share/backgrounds/macos/sonoma.jpg
LOG="$HOME/macos-setup.log"

log() { echo "[macos-setup] $*" >>"$LOG" 2>&1; echo "[macos-setup] $*" >/dev/ttyS0 2>/dev/null || true; }

log "started as $(id -un); DISPLAY=$DISPLAY; DBUS=$DBUS_SESSION_BUS_ADDRESS"

# Visible probe: open a terminal so we can confirm autostart actually ran.
xfce4-terminal 2>>"$LOG" &

# Retry for ~30s while xfsettingsd / xfdesktop come up under slow emulation.
i=0
while [ $i -lt 15 ]; do
    xfconf-query -c xsettings -p /Net/ThemeName     -s "WhiteSur-Light-blue" 2>>"$LOG"
    xfconf-query -c xsettings -p /Net/IconThemeName -s "WhiteSur"            2>>"$LOG"
    xfconf-query -c xfwm4     -p /general/theme     -s "WhiteSur-Light-blue" 2>>"$LOG"

    if [ -f "$IMG" ]; then
        # set wallpaper on every monitor/workspace xfdesktop reports
        xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E '/last-image$' | while read -r p; do
            xfconf-query -c xfce4-desktop -p "$p" -s "$IMG" 2>>"$LOG"
            style="$(echo "$p" | sed 's,/last-image$,/image-style,')"
            xfconf-query -c xfce4-desktop -p "$style" -s 5 2>>"$LOG"
        done
        # seed common monitor names if none exist yet
        for m in monitorVirtual-1 monitorVirtual1 monitor0 monitordefault monitorscreen Virtual-1; do
            base="/backdrop/screen0/$m/workspace0"
            xfconf-query -c xfce4-desktop -p "$base/last-image"  -n -t string -s "$IMG" 2>/dev/null
            xfconf-query -c xfce4-desktop -p "$base/image-style" -n -t int    -s 5      2>/dev/null
        done
    fi
    xfdesktop --reload 2>>"$LOG"

    pgrep -x picom >/dev/null || picom -b 2>>"$LOG"
    pgrep -x plank >/dev/null || plank >>"$LOG" 2>&1 &

    n_last=$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -cE '/last-image$')
    log "iter=$i monitors_with_last-image=$n_last plank=$(pgrep -x plank|head -1)"
    i=$((i + 1))
    sleep 2
done
log "done"

#!/bin/sh
# Lock in the macOS look once the XFCE session is up. Run from
# ~/.config/autostart/zz-macos-setup.desktop. Retries while the session
# settles (slow under emulation).
IMG=/usr/share/backgrounds/macos/sonoma.jpg
PLANK="net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/"

# --- Plank dock: it reads dconf (not the settings file), so configure here ---
gsettings set "$PLANK" hide-mode  'none'                                     2>/dev/null
gsettings set "$PLANK" position   'bottom'                                   2>/dev/null
gsettings set "$PLANK" alignment  'center'                                   2>/dev/null
gsettings set "$PLANK" icon-size  48                                         2>/dev/null
gsettings set "$PLANK" zoom-enabled true                                     2>/dev/null
gsettings set "$PLANK" theme      'Transparent'                              2>/dev/null
gsettings set "$PLANK" dock-items "['thunar.dockitem', 'xfce4-terminal.dockitem', 'xfce4-appfinder.dockitem', 'xfce-settings-manager.dockitem']" 2>/dev/null

i=0
while [ $i -lt 12 ]; do
    # GTK / window-manager / icon theme
    xfconf-query -c xsettings -p /Net/ThemeName     -s "WhiteSur-Light-blue" 2>/dev/null
    xfconf-query -c xsettings -p /Net/IconThemeName -s "WhiteSur"            2>/dev/null
    xfconf-query -c xfwm4     -p /general/theme     -s "WhiteSur-Light-blue" 2>/dev/null

    # Wallpaper on every monitor/workspace xfdesktop actually reports
    if [ -f "$IMG" ]; then
        xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E '/last-image$' | while read -r p; do
            xfconf-query -c xfce4-desktop -p "$p" -s "$IMG" 2>/dev/null
            xfconf-query -c xfce4-desktop -p "$(echo "$p" | sed 's,/last-image$,/image-style,')" -s 5 2>/dev/null
        done
        xfdesktop --reload 2>/dev/null
    fi

    # keep the dock + compositor alive
    pgrep -x picom >/dev/null || picom -b 2>/dev/null
    pgrep -x plank >/dev/null || plank >/dev/null 2>&1 &

    i=$((i + 1))
    sleep 2
done

#!/bin/sh
# Sourced by startxfce4 at the start of every XFCE session. This is more
# reliable than ~/.config/autostart for live sessions, so we drive the macOS
# look (theme, wallpaper, dock, compositor) from here.
/usr/local/bin/macos-setup.sh >/dev/null 2>&1 &

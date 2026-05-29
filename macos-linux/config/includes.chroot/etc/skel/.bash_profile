# Start the graphical desktop automatically when the live user logs in on tty1.
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ] && ! pgrep -x Xorg >/dev/null; then
    exec startx
fi

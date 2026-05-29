#!/bin/bash
# stage-theme.sh — download + install the macOS (WhiteSur) theme, icons, and
# wallpaper into config/includes.chroot so the live-build run just copies them
# into the image. Runs on the HOST (where networking + CA certs work), which
# is more robust than cloning inside the build chroot.
#
# Requires on the host: git, sassc, libglib2.0-dev-bin, imagemagick.
set -e
cd "$(dirname "$0")"

DEST="config/includes.chroot"
THEMES="$PWD/$DEST/usr/share/themes"
ICONS="$PWD/$DEST/usr/share/icons"
BG="$PWD/$DEST/usr/share/backgrounds/macos"
mkdir -p "$THEMES" "$ICONS" "$BG"

# Allow pointing at an existing checkout (e.g. offline) via THEME_SRC.
if [ -n "$THEME_SRC" ] && [ -d "$THEME_SRC" ]; then
    WORK="$THEME_SRC"
    CLEAN=""
else
    WORK="$(mktemp -d)"
    CLEAN="$WORK"
    echo "==> Cloning WhiteSur theme/icons/wallpapers..."
    git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git   "$WORK/WhiteSur-gtk-theme"
    git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git  "$WORK/WhiteSur-icon-theme"
    git clone --depth=1 https://github.com/vinceliuice/WhiteSur-wallpapers.git  "$WORK/WhiteSur-wallpapers"
fi
[ -n "$CLEAN" ] && trap 'rm -rf "$CLEAN"' EXIT

echo "==> Installing GTK theme -> $THEMES"
# Install each color variant separately; the WhiteSur installer aborts on its
# (optional) GNOME-Shell step when gnome-shell isn't present, but the GTK
# theme for that variant is already written by then, so tolerate non-zero.
for variant in Light Dark; do
    ( cd "$WORK/WhiteSur-gtk-theme" && ./install.sh -d "$THEMES" -c "$variant" -t blue ) \
        || echo "   (installer returned non-zero for $variant; GTK theme part is installed)"
done

echo "==> Installing icon theme -> $ICONS"
( cd "$WORK/WhiteSur-icon-theme" && ./install.sh -d "$ICONS" ) \
    || echo "   (icon installer returned non-zero; check $ICONS)"

echo "==> Installing wallpaper -> $BG/sonoma.jpg"
cp "$(ls "$WORK"/WhiteSur-wallpapers/4k/*onoma* 2>/dev/null | head -1)"   "$BG/sonoma.jpg" 2>/dev/null \
  || cp "$(ls "$WORK"/WhiteSur-wallpapers/1080p/*onoma* 2>/dev/null | head -1)" "$BG/sonoma.jpg" 2>/dev/null \
  || cp "$(ls "$WORK"/WhiteSur-wallpapers/4k/*.jpg 2>/dev/null | head -1)"  "$BG/sonoma.jpg" 2>/dev/null \
  || convert -size 1920x1080 gradient:'#1e3a8a'-'#7c3ac8' "$BG/sonoma.jpg"

echo "==> Theme staged."

#!/bin/bash
# build.sh — build the macOS Sonoma-themed Ubuntu live ISO.
#
#   sudo ./build.sh         # configure + build -> live-image-amd64.hybrid.iso
#   sudo ./build.sh clean   # remove build artifacts (keeps config/)
#
# Requires: live-build, debootstrap, squashfs-tools, xorriso  (Ubuntu host).
set -e
cd "$(dirname "$0")"

if [ "$1" = "clean" ]; then
    lb clean --purge || true
    exit 0
fi

# Stage the macOS theme/icons/wallpaper on the host into includes.chroot
# (skippable with SKIP_STAGE=1 if you've already staged it).
if [ "${SKIP_STAGE:-0}" != "1" ]; then
    ./stage-theme.sh
fi

# Configure the live system. We target the host's Ubuntu release so the
# package mirrors match and debootstrap is happy.
RELEASE="${RELEASE:-noble}"

lb config noauto \
    --distribution "$RELEASE" \
    --architectures amd64 \
    --archive-areas "main restricted universe multiverse" \
    --binary-images iso-hybrid \
    --bootloader grub2 \
    --debian-installer false \
    --apt-indices false \
    --apt-recommends true \
    --memtest none \
    --bootappend-live "boot=live components quiet splash hostname=macos username=mac" \
    "${@}"

# Build it (downloads packages, builds the squashfs, makes the ISO).
lb build

echo
echo "==> Done. ISO: $(ls -1 *.iso 2>/dev/null | head -1)"

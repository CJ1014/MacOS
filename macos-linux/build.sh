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

# Build the live filesystem. NOTE: on recent Ubuntu, live-build's own
# bootloader/ISO stage is broken (missing gfxboot-theme-ubuntu, broken
# grub-mkimage, missing isohybrid). The chroot + squashfs + kernel/initrd are
# produced *before* that stage, so we tolerate its failure and then build a
# clean bootable ISO ourselves with grub-mkrescue.
lb build || echo "==> (live-build bootloader stage failed as expected; assembling ISO directly)"

# Assemble the bootable hybrid ISO from the live filesystem tree.
./make-iso.sh "${OUT_ISO:-macos-sonoma.iso}"

echo
echo "==> Done. ISO: $(ls -1 *.iso 2>/dev/null | head -1)"

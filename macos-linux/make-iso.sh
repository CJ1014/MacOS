#!/bin/bash
# make-iso.sh — assemble a bootable hybrid ISO from the live filesystem tree
# that `lb build` produced (chroot/binary/), using grub-mkrescue.
#
# We do this instead of relying on live-build's own bootloader stage, which is
# broken on recent Ubuntu (missing gfxboot-theme-ubuntu, broken grub-mkimage
# invocation, missing isohybrid). grub-mkrescue produces a clean BIOS+UEFI
# hybrid ISO that boots in VirtualBox/QEMU.
set -e
cd "$(dirname "$0")"

BIN="chroot/binary"
[ -d "$BIN/casper" ] || BIN="binary"
[ -d "$BIN/casper" ] || { echo "ERROR: live filesystem tree not found (run build.sh first)"; exit 1; }

OUT="${1:-macos-sonoma.iso}"
ISOROOT="isoroot"
sudo rm -rf "$ISOROOT"
mkdir -p "$ISOROOT"
# hardlink-copy the tree (fast, no extra space) — same filesystem required
sudo cp -al "$BIN"/. "$ISOROOT"/

VMLINUZ="$(cd "$ISOROOT/casper" && ls vmlinuz* | head -1)"
INITRD="$(cd "$ISOROOT/casper"  && ls initrd*  | head -1)"

sudo mkdir -p "$ISOROOT/boot/grub"
sudo tee "$ISOROOT/boot/grub/grub.cfg" >/dev/null <<EOF
set timeout=3
set default=0
insmod all_video

menuentry "macOS-style Linux (live)" {
    linux /casper/$VMLINUZ boot=casper username=mac hostname=macos quiet splash ---
    initrd /casper/$INITRD
}
menuentry "macOS-style Linux (safe graphics)" {
    linux /casper/$VMLINUZ boot=casper username=mac hostname=macos nomodeset ---
    initrd /casper/$INITRD
}
EOF

sudo grub-mkrescue -o "$OUT" "$ISOROOT" 2>/dev/null
sudo rm -rf "$ISOROOT"
echo "==> Built $OUT ($(du -h "$OUT" | cut -f1))"

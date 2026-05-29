# Build the AquaOS bootable ISO from scratch.
#
#   make        -> build/aquaos.iso   (boot this in VirtualBox / QEMU)
#   make run    -> boot the ISO in QEMU
#   make clean  -> remove build artifacts

CC      := gcc
LD      := ld
ASM     := nasm

CFLAGS  := -m32 -ffreestanding -fno-stack-protector -fno-pic -nostdlib \
           -Wall -Wextra -O2 -std=gnu11
LDFLAGS := -m elf_i386 -T linker.ld -nostdlib

BUILD   := build
ISODIR  := $(BUILD)/isodir
KERNEL  := $(BUILD)/kernel.elf
ISO     := $(BUILD)/aquaos.iso

OBJS    := $(BUILD)/boot.o $(BUILD)/kernel.o

.PHONY: all run clean
all: $(ISO)

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/boot.o: src/boot.asm | $(BUILD)
	$(ASM) -f elf32 $< -o $@

$(BUILD)/kernel.o: src/kernel.c src/font8x8.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(KERNEL): $(OBJS) linker.ld
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

$(ISO): $(KERNEL) grub/grub.cfg
	mkdir -p $(ISODIR)/boot/grub
	cp $(KERNEL) $(ISODIR)/boot/kernel.elf
	cp grub/grub.cfg $(ISODIR)/boot/grub/grub.cfg
	grub-mkrescue -o $@ $(ISODIR) 2>/dev/null

run: $(ISO)
	qemu-system-x86_64 -cdrom $(ISO) -m 256 -vga std

clean:
	rm -rf $(BUILD)

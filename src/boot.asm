; boot.asm — Multiboot2 header + 32-bit entry point for AquaOS.
;
; GRUB loads us in 32-bit protected mode (per the Multiboot2 spec) and, because
; we ask for it below, hands us a linear graphics framebuffer. We set up a
; stack, pass the Multiboot2 info pointer + magic to the C kernel, and never
; return.

MB2_MAGIC      equ 0xE85250D6      ; Multiboot2 magic
MB2_ARCH       equ 0               ; 0 = i386 (32-bit protected mode)

section .multiboot
align 8
header_start:
    dd MB2_MAGIC
    dd MB2_ARCH
    dd header_end - header_start                              ; header length
    dd -(MB2_MAGIC + MB2_ARCH + (header_end - header_start))  ; checksum

    ; --- Framebuffer request tag: ask GRUB for a graphics mode ---
align 8
fb_tag_start:
    dw 5                            ; type = framebuffer
    dw 0                            ; flags
    dd fb_tag_end - fb_tag_start    ; size
    dd 1024                         ; preferred width
    dd 768                          ; preferred height
    dd 32                           ; preferred bits-per-pixel
fb_tag_end:

    ; --- End tag ---
align 8
    dw 0                            ; type = end
    dw 0                            ; flags
    dd 8                            ; size
header_end:

; mark the stack non-executable (silences a linker warning)
section .note.GNU-stack noalloc noexec nowrite progbits

section .bss
align 16
stack_bottom:
    resb 32768                      ; 32 KiB kernel stack
stack_top:

section .text
global _start
extern kmain
_start:
    mov esp, stack_top              ; set up our stack
    push ebx                        ; arg2: pointer to Multiboot2 info
    push eax                        ; arg1: Multiboot2 magic (0x36d76289)
    call kmain
.hang:
    cli
    hlt
    jmp .hang

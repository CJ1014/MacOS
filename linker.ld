/* linker.ld — places the AquaOS kernel at the conventional 1 MiB mark and
   makes sure the Multiboot2 header lands in the first 8 KiB so GRUB finds it. */

ENTRY(_start)

SECTIONS
{
    . = 1M;

    .text BLOCK(4K) : ALIGN(4K)
    {
        *(.multiboot)   /* Multiboot2 header must come first */
        *(.text)
    }

    .rodata BLOCK(4K) : ALIGN(4K)
    {
        *(.rodata)
    }

    .data BLOCK(4K) : ALIGN(4K)
    {
        *(.data)
    }

    .bss BLOCK(4K) : ALIGN(4K)
    {
        *(COMMON)
        *(.bss)
    }
}

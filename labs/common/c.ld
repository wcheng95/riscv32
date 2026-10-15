/* Minimal RV32I bare-metal C layout (Lab13).
 * Program at 0, RAM at 0x1000-0x1fff, stack from 0x2000 down.
 */
OUTPUT_ARCH(riscv)
ENTRY(_start)
SECTIONS
{
    . = 0;
    .text : { KEEP(*(.text.start)) *(.text .text.*) *(.rodata .rodata.*) }
    . = ALIGN(4);
    .data : { *(.data .data.*) }
    .bss (NOLOAD) : { *(.bss .bss.*) *(COMMON) }
    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
ASSERT(SIZEOF(.data) == 0 && SIZEOF(.bss) == 0, "Lab13 intentionally has no global C runtime data");

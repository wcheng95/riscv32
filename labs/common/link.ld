/* Shared minimal RV32I bare-metal image layout for Lab00 and Lab01. */
OUTPUT_ARCH(riscv)
ENTRY(_start)
SECTIONS
{
    . = 0x00000000;
    .text : { *(.text .text.*) }
    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}

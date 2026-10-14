.section .text
.globl _start
_start:
    .word 0xffffffff      # deliberately unsupported opcode
    jal x0, .             # must not execute

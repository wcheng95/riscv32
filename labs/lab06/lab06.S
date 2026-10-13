.section .text
.globl _start
_start:
    lui  x4, 0x1
    addi x5, x0, 42
    sw   x5, 0(x4)
    lw   x6, 0(x4)
    addi x6, x6, 1
    sw   x6, 4(x4)
park:
    jal  x0, park

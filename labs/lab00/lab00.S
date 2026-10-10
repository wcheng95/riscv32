.section .text
.globl _start
_start:
    addi x1, x0, 5
    addi x2, x0, 7
    add  x3, x1, x2
    lui  x4, 0x1
    sw   x3, 0(x4)
park:
    jal  x0, park

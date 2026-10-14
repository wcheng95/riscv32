.section .text
.globl _start
_start:
    lui  x4, 0x1
    addi x1, x0, 5
    addi x2, x0, 7
    .word 0x0020818b       # custom-0: x3 = x1 + x2 + 1 (PCPI demo)
    sw   x3, 0(x4)         # expect 13
    addi x5, x3, 1
    sw   x5, 4(x4)         # expect 14
park:
    jal x0, park

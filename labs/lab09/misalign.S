.section .text
.globl _start
_start:
    lui  x1, 0x1          # x1 = 0x1000
    lw   x2, 2(x1)        # word load at 0x1002: misaligned
    jal  x0, .           # must not execute

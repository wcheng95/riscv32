.section .text
.globl _start
_start:
    addi x1, x0, -1        # all ones: 0xffffffff
    addi x2, x0, 1
    srli x3, x1, 1         # logical: 0x7fffffff
    srai x5, x1, 1         # arithmetic: 0xffffffff
    sltu x6, x2, x1        # unsigned: 1 < 0xffffffff => 1
    slt  x7, x1, x2        # signed: -1 < 1 => 1
    lui  x4, 0x1
    sw   x3, 0(x4)
    sw   x5, 4(x4)
    sw   x6, 8(x4)
    sw   x7, 12(x4)
park:
    jal x0, park

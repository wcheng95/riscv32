.section .text
.globl _start
_start:
    lui  x4, 0x1         # result base 0x1000
    addi x1, x0, 6
    addi x2, x0, 11
    add  x3, x1, x2     # 17; reads two source registers
    sub  x5, x2, x1     # 5
    sll  x6, x5, x1     # 5 << 6 = 320
    xor  x7, x3, x6     # 17 ^ 320 = 337 (0x151)
    sw   x3, 0(x4)
    sw   x7, 4(x4)
park:
    jal  x0, park

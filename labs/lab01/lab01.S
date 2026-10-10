.section .text
.globl _start
_start:
    addi x1, x0, 5          # x1 = 5
    addi x0, x1, 9          # attempted write to x0 is discarded
    addi x2, x0, -3         # sign-extended 12-bit immediate
    add  x31, x1, x2        # last integer register = 2
    lui  x4, 0x1            # result area = 0x1000
    sw   x0, 0(x4)          # 0: x0 must remain zero
    sw   x2, 4(x4)          # 4: 0xfffffffd
    sw   x31, 8(x4)         # 8: 2
    sw   x1, 12(x4)         # 12: 5
park:
    jal  x0, park

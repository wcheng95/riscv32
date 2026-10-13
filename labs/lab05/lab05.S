.section .text
.globl _start
_start:
    lui  x4, 0x1
    addi x1, x0, -1
    addi x2, x0, 1
    blt  x1, x2, signed_ok    # signed: -1 < 1, taken
    sw   x0, 16(x4)          # forbidden
signed_ok:
    bltu x1, x2, bad         # unsigned: 0xffffffff < 1, not taken
    bgeu x1, x2, unsigned_ok # unsigned: 0xffffffff >= 1, taken
bad:
    sw   x0, 16(x4)          # forbidden
unsigned_ok:
    jal  x6, after_j         # x6 = PC+4 = 0x24
    sw   x0, 16(x4)          # forbidden
after_j:
    sw   x6, 0(x4)           # save JAL link
    auipc x8, 0              # PC = 0x2c
    addi x8, x8, 17         # 0x3d; JALR clears bit 0 => 0x3c
    jalr x9, 0(x8)          # link = 0x38
    sw   x0, 16(x4)          # forbidden
target:
    sw   x9, 4(x4)
    sw   x1, 8(x4)
    sw   x2, 12(x4)
park:
    jal x0, park

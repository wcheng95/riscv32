.section .text
.globl _start
_start:
    addi x1, x0, 5         # I: x1 = 5
    addi x2, x0, 7         # I: x2 = 7
    add  x3, x1, x2        # R: x3 = 12
    lui  x4, 0x1           # U: base = 0x1000
    auipc x5, 0            # U: x5 = address of this instruction (0x10)
    beq  x3, x0, wrong     # B: not taken
    beq  x3, x3, after_b   # B: taken (+8)
wrong:
    sw   x0, 12(x4)        # forbidden store: branch must skip
after_b:
    sw   x3, 0(x4)         # S: RAM[0x1000] = 12
    jal  x6, after_j       # J: x6 = return PC (0x28)
    sw   x0, 12(x4)        # forbidden store: jump must skip
after_j:
    sw   x6, 4(x4)         # S: RAM[0x1004] = 0x28
    sw   x5, 8(x4)         # S: RAM[0x1008] = 0x10
park:
    jal  x0, park

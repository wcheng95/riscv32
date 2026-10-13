.section .text
.globl _start
_start:
    lui x4, 0x1
    .word 0xc0002573       # rdcycle x10 (CSR cycle = 0xc00)
    .word 0xc02025f3       # rdinstret x11 (CSR instret = 0xc02)
    addi x1, x0, 1
    addi x2, x0, 4
loop:
    addi x1, x1, 1
    addi x2, x2, -1
    bne  x2, x0, loop
    .word 0xc0002673       # rdcycle x12
    .word 0xc02026f3       # rdinstret x13
    sub  x14, x12, x10
    sub  x15, x13, x11
    sw   x1, 0(x4)         # 5
    sw   x14, 4(x4)        # elapsed hardware cycles
    sw   x15, 8(x4)        # retired-instruction delta
park:
    jal x0, park

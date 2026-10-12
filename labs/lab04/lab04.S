.section .text
.globl _start
_start:
    lui  x4, 0x1
    lui  x2, 0x80ff8
    addi x2, x2, -255       # x2 = 0x80ff7f01
    sw   x2, 0(x4)          # bytes in RAM: 01 7f ff 80
    lb   x5, 1(x4)          # signed byte: 0x0000007f
    lbu  x6, 2(x4)          # unsigned byte: 0x000000ff
    lh   x7, 2(x4)          # signed half: 0xffff80ff
    lhu  x8, 2(x4)          # unsigned half: 0x000080ff
    sw   x5, 4(x4)
    sw   x6, 8(x4)
    sw   x7, 12(x4)
    sw   x8, 16(x4)
    sb   x2, 21(x4)         # write byte lane 1 at 0x1014
    sh   x2, 22(x4)         # write halfword lanes 2,3
    lw   x9, 20(x4)         # initially NOP word 0x00000013
    sw   x9, 24(x4)        # expect 0x7f010113 (low byte remains 0x13)
park:
    jal x0, park

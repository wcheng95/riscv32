.section .text
.globl _start
_start:
    lui  x4, 0x1
    addi x5, x0, -9         # 0xfffffff7: unmask IRQ3 only
    .word 0x0602800b       # maskirq x0,x5 (PicoRV32 custom instruction)
    addi x9, x0, 165
poll:
    lw   x8, 0(x4)         # wait until handler marks RAM[0x1000]
    bne  x8, x9, poll
    addi x10, x0, 90
    sw   x10, 4(x4)        # main resumed: RAM[0x1004] = 0x5a
park:
    jal  x0, park

    .org 0x80
irq_handler:
    lui  x6, 0x1
    addi x7, x0, 165
    sw   x7, 0(x6)         # handler: RAM[0x1000] = 0xa5
    .word 0x0400000b       # retirq (PicoRV32 custom instruction)

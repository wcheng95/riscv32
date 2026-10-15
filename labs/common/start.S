.section .text.start,"ax"
.globl _start
_start:
    lui sp, 0x2            # RAM 0x0000-0x1fff; stack starts just above RAM
    call main              # ABI: return address in ra
1:
    jal x0, 1b             # park if main returns

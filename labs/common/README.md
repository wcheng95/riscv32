# Shared Lab Infrastructure

This directory owns the minimum shared linker configuration for the RV32I labs.

## link.ld

- `OUTPUT_ARCH(riscv)`: [LD] identifies the ELF machine architecture.
- `ENTRY(_start)`: [LD] selects the ELF entry symbol; [CONV] our CPU still begins at `PROGADDR_RESET=0`.
- `. = 0x00000000`: [CONV] locate program bytes at reset address 0.
- `.text`: [LD] collects executable code in order.
- `/DISCARD/`: [LD] excludes unrelated metadata from our tiny ROM image.

There is intentionally **no shared start.S yet**. Lab00 and Lab01 each define `_start` directly; there are no C runtime initialization, stack setup, .data/.bss initialization or function calls to share. When the C/ABI lab needs startup code, introduce `start.S` then instead of adding an unused abstraction now.

This separation follows `cisc68k`'s documentation conventions, not its 68000-specific reset vector mechanism. RISC-V reset starts from `PROGADDR_RESET`, not a pair of memory-resident reset vectors.

**Ownership:** linker placement is shared; each lab owns its instructions and checks; upstream PicoRV32 RTL is not modified.

# Shared Lab Infrastructure

This directory owns the minimum shared linker configuration for the RV32I labs.

## link.ld

- `OUTPUT_ARCH(riscv)`: [LD] identifies the ELF machine architecture.
- `ENTRY(_start)`: [LD] selects the ELF entry symbol; [CONV] our CPU still begins at `PROGADDR_RESET=0`.
- `. = 0x00000000`: [CONV] locate program bytes at reset address 0.
- `.text`: [LD] collects executable code in order.
- `/DISCARD/`: [LD] excludes unrelated metadata from our tiny ROM image.

Lab13 adds **start.S** for C startup. Earlier assembly-only labs still define their own `_start`. Lab00 and Lab01 each define `_start` directly; there are no C runtime initialization, stack setup, .data/.bss initialization or function calls to share. `start.S` initializes the stack pointer to `0x2000`, calls `main`, and parks on return. `c.ld` is a separate minimal C linker layout. It intentionally excludes initialized globals and BSS until we implement proper C runtime initialization.

This separation follows `cisc68k`'s documentation conventions, not its 68000-specific reset vector mechanism. RISC-V reset starts from `PROGADDR_RESET`, not a pair of memory-resident reset vectors.

**Ownership:** linker placement is shared; each lab owns its instructions and checks; upstream PicoRV32 RTL is not modified.

## Lab13 C entry and linker

`start.S` initializes `sp=0x2000` (the first address above the 8 KiB RAM) and calls `main` using the RV32I ABI. `c.ld` places code at PC 0, with no .data/.bss runtime support. These files are shared infrastructure, not PicoRV32 RTL modifications.

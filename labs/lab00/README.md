# Lab00 — PicoRV32 Standalone Sanity Check

## Goal

Prove the minimal route: reset → instruction fetch → ALU → store → self-checking testbench.

## Program

```asm
addi x1, x0, 5
addi x2, x0, 7
add  x3, x1, x2
lui  x4, 0x1
sw   x3, 0(x4)
park:
    jal x0, park
```

The source is `labs/lab00/lab00.S`. The shared linker script `labs/common/link.ld` places it at PC=0. GNU GCC/binutils produce an ELF, raw binary and `build/lab00.hex`; the testbench loads that hex file using `$readmemh`.

## Memory

```text
0x0000     first instruction
0x0014     infinite loop
0x1000     result = 12
0x1fff     end of 8 KiB RAM
```

## Build and run

```sh
make test LAB=lab00
make disasm LAB=lab00
make wave LAB=lab00
```

Expected decisive lines:

```text
STORE addr=00001000 value=0000000c wstrb=1111
PASS: Lab00 result=12 cycles=...
```

The cycle count is measured by the testbench; it is not an ISA-defined instruction count. A timeout, trap or wrong store must fail simulation.

## Bus trace

```sh
make trace LAB=lab00
cat build/bus.trace
```

See [trace format](../../docs/trace.md). Each row represents one completed native-memory transfer; the trace is separate from VCD waveform output.

## Signals to inspect

`resetn`, `trap`, `mem_valid`, `mem_ready`, `mem_instr`, `mem_addr`, `mem_wdata`, `mem_wstrb`, `mem_rdata`.

## Questions

1. Why is `x0` always zero?
2. Why do we need `lui` to construct address `0x1000`?
3. How does a store differ from an instruction fetch on the native bus?
4. Which cycle asserts `mem_ready`?
5. Which details are ISA rules and which are PicoRV32 or testbench choices?

## Historical Mac mini Result (2026-10-10, before assembly-image refactor)

Validated on macOS with Icarus Verilog 13.0, RISC-V GCC 16.2.0 and Binutils 2.47.20260726:

```text
iverilog -g2012 -s riscv32_tb -o build/lab00.vvp tbench/riscv32_tb.v picorv32/picorv32.v
vvp build/lab00.vvp
STORE addr=00001000 value=0000000c wstrb=1111
PASS: Lab00 result=12 cycles=27
tbench/riscv32_tb.v:90: $finish called at 375000 (1ps)
```

The *original hardcoded-opcode* version passed on the Mac mini. The testbench now loads a compiled assembly image with the same six instructions. A new Mac mini run is required to verify the revised build. The counted 27 cycles are not the CPI of an individual instruction.

## Completion

**Previously PASS; updated assembly-based flow pending revalidation.** No change to the expected store (12 at 0x1000); new toolchain flow must be checked with `make clean && make test LAB=lab00`.

## Shared Testbench Update

The simulation now uses `tbench/riscv32_tb.v` together with `tbench/ram.v` and `tbench/bus_trace.v`. The original per-lab passing result above predates this refactor; the common simulation machine must be revalidated with `make test LAB=lab00`.

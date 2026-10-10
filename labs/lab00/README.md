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

The program words are initialized in `tbench/riscv32_tb.v`, not yet compiled using the GNU toolchain.

## Memory

```text
0x0000     first instruction
0x0014     infinite loop
0x1000     result = 12
0x1fff     end of 8 KiB RAM
```

## Build and run

```sh
make test
make wave
```

Expected decisive lines:

```text
STORE addr=00001000 value=0000000c wstrb=1111
PASS: Lab00 result=12 cycles=...
```

The cycle count is measured by the testbench; it is not an ISA-defined instruction count. A timeout, trap or wrong store must fail simulation.

## Signals to inspect

`resetn`, `trap`, `mem_valid`, `mem_ready`, `mem_instr`, `mem_addr`, `mem_wdata`, `mem_wstrb`, `mem_rdata`.

## Questions

1. Why is `x0` always zero?
2. Why do we need `lui` to construct address `0x1000`?
3. How does a store differ from an instruction fetch on the native bus?
4. Which cycle asserts `mem_ready`?
5. Which details are ISA rules and which are PicoRV32 or testbench choices?

## Observed Mac mini Result (2026-10-10)

Validated on macOS with Icarus Verilog 13.0, RISC-V GCC 16.2.0 and Binutils 2.47.20260726:

```text
iverilog -g2012 -s riscv32_tb -o build/lab00.vvp tbench/riscv32_tb.v picorv32/picorv32.v
vvp build/lab00.vvp
STORE addr=00001000 value=0000000c wstrb=1111
PASS: Lab00 result=12 cycles=27
tbench/riscv32_tb.v:90: $finish called at 375000 (1ps)
```

The testbench passed on the user's Mac mini. Waveform inspection remains optional follow-up; the counted 27 cycles are not the CPI of an individual instruction.

## Completion

**PASS — functional sanity check complete.** CPU simulation compiled and the self-checking store completed correctly. VCD capture/inspection has not yet been reported.

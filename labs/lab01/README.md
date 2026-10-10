# Lab01 — RV32I Register Model and PC

## Goal

Study the architectural integer registers and reset PC using the unchanged PicoRV32 RTL.

- `x0` always reads as zero, even after an attempted write.
- `x1`–`x31` are general-purpose 32-bit registers in RV32I; test `x31` explicitly.
- An I-type immediate is sign-extended, including negative values.
- The reset PC is `0x00000000` in our CPU configuration; normal 32-bit instructions advance it by 4.

## Program

See `lab01.S`. The code performs:

```asm
addi x1, x0, 5
addi x0, x1, 9
addi x2, x0, -3
add  x31, x1, x2
lui  x4, 0x1
sw   x0, 0(x4)
sw   x2, 4(x4)
sw   x31, 8(x4)
sw   x1, 12(x4)
park: jal x0, park
```

The stores make internal register results visible through the CPU's architectural memory interface rather than using hierarchical testbench access to CPU registers.

## Build and run (Mac mini)

```sh
make test LAB=lab01
make disasm LAB=lab01
make wave LAB=lab01
```

Required tools: Homebrew `icarus-verilog`, `riscv64-elf-gcc`, and Python 3.

The toolchain uses `-march=rv32i -mabi=ilp32 -nostdlib -nostartfiles`. GNU `objcopy` emits a raw little-endian binary, and `tools/bin2hex.py` turns it into one instruction word per line for `$readmemh`.

## Expected results

| Address | Value | Meaning |
| --- | --- | --- |
| `0x1000` | `00000000` | Attempted write to x0 was ignored |
| `0x1004` | `fffffffd` | x2 = -3, sign-extended |
| `0x1008` | `00000002` | x31 = 5 + (-3) |
| `0x100c` | `00000005` | x1 retained 5 |

Expected last line:

```text
PASS: Lab01 x0=0 x2=-3 x31=2 x1=5 cycles=...
```

The testbench checks the first nine sequential instruction fetch addresses, every word store, and final RAM contents. A trap or timeout fails the test. Observed on Mac mini: 52 testbench cycles.

## Bus trace

```sh
make trace LAB=lab01
cat build/bus.trace
```

See [trace format](../../docs/trace.md). Each row represents one completed native-memory transfer; the trace is separate from VCD waveform output.

## Waveform inspection

Inspect `resetn`, `mem_valid`, `mem_ready`, `mem_instr`, `mem_addr`, `mem_wdata`, `mem_wstrb` and `trap`.

Observe how instruction fetches progress at PC 0, 4, 8, ... 32 while stores visit data addresses 0x1000–0x100c.

## Questions

1. [ISA] Why does writing x0 not change its value?
2. [ISA] Why is x31 no different architecturally from x1?
3. [ISA] Why does `addi x2,x0,-3` yield 0xfffffffd?
4. [PICO] Why can instruction fetch take multiple cycles despite a 4-byte PC step?
5. [CONV] Why does our testbench use memory stores rather than inspecting PicoRV32's register-file implementation directly?

## Observed Mac mini result (2026-10-10)

```text
STORE 0 addr=00001000 data=00000000
STORE 1 addr=00001004 data=fffffffd
STORE 2 addr=00001008 data=00000002
STORE 3 addr=0000100c data=00000005
PASS: Lab01 x0=0 x2=-3 x31=2 x1=5 cycles=52
```

GCC 16.2.0 and Icarus Verilog 13.0 were previously verified on this Mac mini. Functional assertions passed with the shared linker/assembly build. `make wave` and disassembly review remain optional inspection steps.

## Completion

**PASS — functional verification complete** on Mac mini. Waveform inspection not yet reported.

## Shared Testbench Update

The simulation now uses `tbench/riscv32_tb.v` together with `tbench/ram.v` and `tbench/bus_trace.v`. The original per-lab passing result above predates this refactor; the common simulation machine must be revalidated with `make test LAB=lab01`.

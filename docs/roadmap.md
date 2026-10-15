# PicoRV32 Lab Roadmap

This document owns the lab sequence and scope. Keep progress and measured results in each `labs/labNN/README.md`, not the root README.

| Lab | Subject | Core learning objective |
| --- | --- | --- |
| 00 | Minimal simulation | Reset, instruction fetch, memory store and PASS/FAIL |
| 01 | Register model and PC | x0, x1–x31, immediates, sequential PC |
| 02 | Instruction encoding | R/I/S/B/U/J formats and field decoding |
| 03 | ALU and shifts | Signedness, logical/arithmetic shift, set-less-than |
| 04 | Loads and stores | Widths, sign extension, byte strobes and alignment |
| 05 | Control flow | Branches, JAL, JALR, PC-relative addresses |
| 06 | Native memory interface | mem_valid/mem_ready, stalls and wait states |
| 07 | CPU timing | Cycle versus retired-instruction counters, interval CPI |
| 08 | Configuration tradeoffs | Register file read-port architecture and elapsed cycles |
| 09 | Traps | Illegal opcode and misaligned load; terminal trap output |
| **10** | **Interrupts** | Custom PicoRV32 IRQ/EOI, masking, entry and return |
| **11** | **PCPI** | External coprocessor handshake and a small example operation |
| 12 | Skipped | RV32M/RV32C experiments intentionally omitted; no implementation planned |
| 13 | Compiler and ABI | Tiny C code, arguments, stack, return values, optimization |

## Study status (2026-10-14)

**Planned PicoRV32 labs complete:** Labs 00–11 and 13 finished; Lab12 deliberately skipped. Lab10 and Lab11 waveform reviews are complete. Lab13 `-O0` and `-Os` both passed (262 and 121 cycles), and the ISA/ABI/compiler questions were reviewed. Continue PicoRV32/RV32I study informally, without a fixed schedule or additional mandatory labs. Measurements and detailed results remain in lab READMEs.

## Lab design rules

- Keep the upstream `picorv32.v` intact; vary build parameters in the testbench.
- Share one simulation machine (`tbench/riscv32_tb.v`), RAM model (`tbench/ram.v`) and passive memory bus monitor (`tbench/bus_trace.v`).
- Use lab-local assembly or C sources and self-checking expectations.
- Add peripheral modules only for experiments that need them.
- Distinguish standard RISC-V ISA behavior from PicoRV32-specific implementation behavior, particularly its custom interrupt controller.
- All generated outputs belong in `build/`.
- Keep measured results, questions and completion in the corresponding lab README.

## Later comparison

If useful at a later date, return to [cisc68k Lab12](https://github.com/wcheng95/cisc68k/blob/main/docs/roadmap.md) for an evidence-based CISC-versus-RISC comparison.

## Sequence decision (2026-10-14)

Lab12's optional RV32M/RV32C extensions were skipped, and Lab13 followed Lab11. The planned sequence is finished.

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
| 12 | Optional ISA extensions | RV32M and RV32C configuration experiments if useful |
| 13 | Compiler and ABI | Tiny C code, arguments, stack, return values, optimization |

## Lab design rules

- Keep the upstream `picorv32.v` intact; vary build parameters in the testbench.
- Share one simulation machine (`tbench/riscv32_tb.v`), RAM model (`tbench/ram.v`) and passive memory bus monitor (`tbench/bus_trace.v`).
- Use lab-local assembly or C sources and self-checking expectations.
- Add peripheral modules only for experiments that need them.
- Distinguish standard RISC-V ISA behavior from PicoRV32-specific implementation behavior, particularly its custom interrupt controller.
- All generated outputs belong in `build/`.
- Keep measured results, questions and completion in the corresponding lab README.

## Later comparison

After the RISC-V survey, return to [cisc68k Lab12](https://github.com/wcheng95/cisc68k/blob/main/docs/roadmap.md) for an evidence-based CISC-versus-RISC comparison.

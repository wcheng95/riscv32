# riscv32

A small RV32I RTL simulation environment for learning the RISC-V ISA and comparing it with Motorola 68000.

## Approach

- CPU reference: [YosysHQ/PicoRV32](https://github.com/YosysHQ/picorv32) (ISC license).
- Keep upstream `picorv32` RTL intact; configure a minimal **RV32I** core using its native valid/ready memory bus.
- Own our testbench, RAM model, assembly/C labs, assertions, and PASS/FAIL results.
- Use Icarus Verilog initially; no FPGA, SoC, AXI, Wishbone, interrupts, PCPI, RV32M, or RV32C in the first milestone.
- Focus on ISA behavior and later compare instruction encoding, compiler output and cycle counts with `cisc68k`.

## Planned layout

```text
rtl/picorv32.v       upstream CPU RTL, with its copyright and license
 tb/tb_picorv32.v   independent self-checking testbench
firmware/hello.S    introductory RV32I program
labs/               progressively larger experiments
docs/architecture.md notes on boundaries and the memory interface
Makefile            test / wave / clean
build/              generated files, ignored by Git
```

The upstream PicoRV32 source should be pinned to a specific commit, and the commit SHA recorded when copied into `rtl/`. Retain the original ISC copyright notice and include its license.

## Lab roadmap (provisional)

1. Boot and execute a small machine-code program, verify a memory write.
2. Registers and immediate operations.
3. ALU operations.
4. Loads, stores and byte enables.
5. Branches and loops.
6. Calls and stack conventions.
7. Instruction formats and address calculation.
8. GCC-generated assembly at `-O0`.
9. Optimization at `-O2`.
10. Cycle counts and memory latency.
11. RV32I versus 68000 comparison.

## Milestone 1 acceptance

- Compile the unmodified PicoRV32 CPU and our testbench using Icarus Verilog.
- Execute a four-instruction RV32I arithmetic-and-store program from a small RAM model.
- Check the expected write to a non-code data address.
- Print `PASS` or `FAIL`, with a bounded timeout.
- Keep all CPU peripherals and extended ISA features disabled.

Status: **Planning** — this README does not claim a completed implementation or passing tests.

# riscv32

Study the RISC-V RV32 architecture using a cycle-visible RTL simulation environment centered on [PicoRV32](https://github.com/YosysHQ/picorv32).

The goal is architectural understanding: RV32I programming model, instruction encoding, memory operations, branches, the native memory interface, execution timing, CPU configuration and compiler-generated code. The CPU reference RTL is preserved **unmodified**. Follow the documentation and lab format of [cisc68k](https://github.com/wcheng95/cisc68k), but let PicoRV32's features determine the lab topics.

## Status

Reference RTL and ISC license imported. Lab00 testbench, Makefile and macOS environment instructions are committed; Lab00 originally passed on Mac mini (Icarus 13.0, store result 12, 27 testbench cycles). Its build is now assembly-based and awaits revalidation. Lab01 passed on Mac mini (four checked stores, 52 testbench cycles).

## Design Decisions

- Preserve upstream `picorv32.v` unchanged, with original copyright/license and a recorded upstream commit SHA.
- Configure the `picorv32` module rather than stripping or editing its internals.
- Begin with RV32I, the PicoRV32 native memory interface, a small RAM and a minimal memory-mapped monitor.
- Develop our own testbench, monitor, self-checking tests and labs.
- Icarus Verilog initially; Verilator and Surfer when useful.
- No FPGA, complete SoC, AXI, Wishbone or operating system.
- Keep RV32M, RV32C, IRQ and PCPI disabled in Lab00. Dedicated later labs will enable **interrupts and PCPI**, without modifying upstream RTL; RV32M/RV32C remain optional.
- Treat peripheral models as a means to observe the CPU interface, not as standalone projects.

## Documentation and Lab Conventions

Follow `cisc68k` in layout and method:

- `docs/mission-scope.md`: mission, boundaries and scope.
- `docs/roadmap.md`: numbered experiments and status.
- `docs/environment.md`: tools, memory map and simulation flow.
- `docs/trace.md`: passive human-readable bus transaction trace.
- `docs/references.md`: reference design, ISA and toolchain.
- `labs/labNN/README.md`: goal, program, expected output, build/run, waveform or disassembly inspection, questions and completion evidence.
- `labs/common/`: minimal shared startup and linker files once assembly/C labs require them.
- `tbench/`: common simulation machine, shared RAM and passive trace; add peripherals only when an experiment requires them.
- `logs/` and `build/`: generated artifacts, not committed.

Distinguish `[ISA]` RISC-V-defined behavior, `[PICO]` PicoRV32 implementation details, `[ASM]` assembler syntax, `[LD]` linker behavior, and `[CONV]` project conventions.

## Planned Layout

```text
riscv32/
├── README.md
├── Makefile
├── picorv32/
│   └── picorv32.v       # exact upstream source
├── tbench/
│   ├── riscv32_tb.v
│   ├── ram.v
│   └── bus_trace.v
├── labs/
│   ├── common/
│   │   ├── README.md
│   │   └── link.ld
│   ├── lab00/
│   │   ├── README.md
│   │   └── lab00.S
│   └── ...
├── docs/
│   ├── mission-scope.md
│   ├── roadmap.md
│   ├── environment.md
│   └── references.md
├── build/                # ignored
└── logs/                 # ignored
```

The upstream RTL, common testbench, shared RAM/trace modules and first two assembly labs are present. Other entries are the planned layout. A shared `start.S` will be introduced when a lab actually needs common startup.

## Roadmap (Provisional)

| Lab | Subject | Specific observation |
| --- | --- | --- |
| 00 | Minimal simulation | Reset, fetch, self-check, monitor write and waveform |
| 01 | Register model and PC | x0, x1–x31, reset entry, register arithmetic (PASS, 52 cycles) |
| 02 | Instruction encoding | R/I/S/B/U/J formats, immediate decoding |
| 03 | ALU and shifts | Operations, signedness, shift timing |
| 04 | Loads and stores | Widths, sign extension, write strobes, alignment |
| 05 | Control flow | Branches, JAL/JALR, PC-relative addressing |
| 06 | Native memory interface | mem_valid/mem_ready, mem_instr, latency and stalls |
| 07 | State machine and CPI | Instruction-dependent cycle counts, memory effects |
| 08 | Configuration tradeoffs | Register ports, shifters, ALU options |
| 09 | Traps and counters | Unsupported/misaligned operations, cycle counters |
| 10 | Interrupt interface | irq/eoi, masking, latching, handler entry/return with custom PicoRV32 instructions |
| 11 | PCPI coprocessor interface | Valid/ready/wait handshake and a minimal external operation |
| 12 | Optional ISA extensions | Configured RV32M/RV32C experiments if useful |
| 13 | Compiler and ABI | Calls, stack, GCC at -O0 and -Os/-O2 |

The PicoRV32 interrupt controller uses custom instructions (not the standard RISC-V privileged CSR / trap interface). The IRQ lab must distinguish this implementation-specific behavior from the RV32I ISA. The PCPI lab must distinguish the external handshake from an ISA extension. 

The learning sequence is intentionally not identical to `cisc68k`. A comparison based on observed results will eventually feed `cisc68k` Lab12.

## First Milestone: Lab00

- Pin and copy unmodified upstream PicoRV32 RTL and license.
- Create an independent minimal testbench and simple native-bus memory model. (Committed)
- Execute a short machine-code program. (Historical PASS with hardcoded opcodes; assembly-based flow pending validation)
- Verify a store to an address separate from program code, then print an explicit `PASS` or `FAIL`.
- Provide a simulation timeout and VCD output.
- Record the exact commands and observed results in `labs/lab00/README.md` once implemented.

## Trace

`make trace LAB=lab00` or `make trace LAB=lab01` produces `build/<lab>.trace` with completed IFETCH, READ and WRITE bus transactions. Trace generation is on by default for `make`, `make test`, `make test-all` and `make wave`; it does not change functional tests. Mac mini trace output awaits validation.

## Scope Rule

Before adding machinery, ask: Which PicoRV32 or RISC-V question does it answer? Can the existing simulator answer it already? Keep the smallest experiment that makes the relevant behavior visible.

## Credits

- [PicoRV32](https://github.com/YosysHQ/picorv32) by Claire Xenia Wolf / YosysHQ — the reference CPU RTL, ISC license.
- [cisc68k](https://github.com/wcheng95/cisc68k) — documentation and experimental lab conventions.
- ChatGPT by OpenAI — study partner for architecture planning, PicoRV32 experiments, RTL/testbench design, debugging and documentation.

## Upstream RTL Provenance

- Source: https://github.com/YosysHQ/picorv32
- Pinned upstream commit: `ef203c2b0a3fb793280f5114941416c425c5b461`
- Imported paths: `picorv32/picorv32.v` and `picorv32/COPYING`
- The RTL is copied verbatim; configuration and simulation belong outside this file.
- Verify exact upstream match using `git show ef203c2b0a3fb793280f5114941416c425c5b461:picorv32.v` in the upstream clone and `cmp` against the local file.

## Shared Simulation Machine

Lab00 and Lab01 use one top-level `tbench/riscv32_tb.v`, shared `ram.v`, and passive `bus_trace.v`. The Makefile selects a lab using VVP plusargs `+lab=<number> +hex=<image> +words=<count>`. New peripherals should be separate modules, added only for labs that need them. The original per-lab Lab01 testbench was retired. Refactored setup awaits Mac mini validation via `make clean && make test-all`.

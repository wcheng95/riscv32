# riscv32

A cycle-visible RISC-V RV32 learning environment using the [PicoRV32](https://github.com/YosysHQ/picorv32) CPU. Explore the ISA, CPU interfaces, execution timing and compiler output using small, self-checking RTL simulations. Lab structure and documentation follow [cisc68k](https://github.com/wcheng95/cisc68k), but experiments focus on PicoRV32.

## Principles

- Keep the upstream `picorv32.v` **unmodified**; configure features through parameters.
- Own the testbench, RAM, passive bus trace, firmware and lab assertions.
- Prefer minimal experiments: modular ownership, decoupling and KISS.
- Add peripherals only when a lab requires them. No FPGA or full SoC is needed.
- Include PicoRV32's custom interrupts and PCPI in dedicated labs; distinguish implementation-specific features from standard RISC-V.

## Repository

```text
picorv32/          Original RTL and ISC license
tbench/            Shared riscv32_tb.v, ram.v, bus_trace.v
labs/common/       Shared linker infrastructure
labs/labNN/        Assembly/C source and individual lab README
docs/              Environment, trace format, architectural notes
tools/             Build helpers
Makefile           Build and simulation commands
build/             Generated binaries, traces and VCDs (ignored)
```

## Quick start (macOS / Homebrew)

```sh
brew install icarus-verilog riscv64-elf-gcc
make test LAB=lab00
make test LAB=lab01
make test-all
make disasm LAB=lab01
make wave LAB=lab01
```

Simulation writes the human-readable native memory bus trace to `build/bus.trace` by default, overwriting it on each run.

## Documentation

- [Environment](docs/environment.md) — toolchain and simulation setup
- [Bus trace](docs/trace.md) — signals, transaction format and usage
- [PicoRV32 RTL reading notes](docs/picorv32-rtl.md) — relaxed side track for reading the core source
- [Lab00](labs/lab00/README.md) and [Lab01](labs/lab01/README.md) — exercises, observations and validation results
- [Shared linker conventions](labs/common/README.md)

Lab progress, measured results, open issues and checkpoints belong in the corresponding lab README or `docs/`, **not here**.

## Upstream and credits

- [PicoRV32](https://github.com/YosysHQ/picorv32) by Claire Xenia Wolf / YosysHQ — ISC-licensed reference CPU. Copied from commit `ef203c2b0a3fb793280f5114941416c425c5b461`; license at [picorv32/COPYING](picorv32/COPYING).
- [cisc68k](https://github.com/wcheng95/cisc68k) — lab and documentation conventions.
- ChatGPT by OpenAI — study partner for design discussion, testbench development, debugging and documentation.

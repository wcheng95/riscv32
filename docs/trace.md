# Human-Readable Native Bus Trace

The shared passive monitor `tbench/bus_trace.v` records completed PicoRV32 native-memory transfers. It never drives signals or changes CPU/memory timing.

## Usage

```sh
make test LAB=lab00
cat build/lab00.trace

make test LAB=lab01
cat build/lab01.trace
```

Human-readable tracing is **on by default** for `make`, `make test`, `make test-all`, `make trace` and `make wave`. The trace is written to a file, not dumped to the terminal. `make wave LAB=...` generates both VCD and trace. Direct VVP execution without `+trace` still disables the optional logger.

## Fields

```text
# CYCLE  TYPE    ADDRESS     DATA        STRB
```

- **CYCLE**: testbench cycle counter at the sampled rising edge, beginning after reset release.
- **IFETCH**: an accepted instruction-fetch read, `mem_instr=1`; DATA is `mem_rdata`, the instruction word supplied by RAM.
- **READ**: a completed data read; DATA is `mem_rdata`.
- **WRITE**: a completed write; DATA is `mem_wdata` and STRB shows enabled byte lanes, with bit 0 for the lowest byte.
- **ADDRESS**: 32-bit byte address in hexadecimal.
- **----**: byte strobes do not apply to reads.

The logger samples **only when** `resetn && mem_valid && mem_ready` at a rising clock edge, preventing repeated records from a stalled transaction. It does not print speculative requests or per-cycle waiting.

The logger uses the same bus signals that the testbench checks. Instruction fetch does **not** imply retirement; internal CPU state and register writes are not logged. For those, use PicoRV32's separate optional `ENABLE_TRACE` facility in a future experiment.

## Implementation

- Module: `tbench/bus_trace.v`
- Instantiated by both `tbench/riscv32_tb.v` and `tbench/lab01_tb.v`
- Activated with VVP plusarg `+trace`
- Outputs: `build/lab00.trace`, `build/lab01.trace`
- Source RTL `picorv32/picorv32.v` is untouched.

## Validation

Pending a Mac mini run of `make trace LAB=lab01` and review of the generated file.

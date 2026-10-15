# Lab11 — PicoRV32 PCPI Coprocessor Handshake

## Goal

Explore the **Pico Co-Processor Interface (PCPI)** without changing upstream PicoRV32 RTL. One independent unit recognizes a single `custom-0` instruction, holds `pcpi_wait` during a short delay, then returns a value with `pcpi_ready` and `pcpi_wr`.

## Design boundaries

- `picorv32.v` remains unmodified. `ENABLE_PCPI=1` only in Lab11, selected at RTL elaboration.
- `tbench/pcpi_demo.v` is a stand-alone external coprocessor. It has no knowledge of lab numbers or memory addresses.
- The shared CPU testbench connects PCPI signals and checks completion; `ram.v` and `bus_trace.v` remain unchanged.
- The coprocessor is not a memory-mapped peripheral. It is invoked through the **instruction stream**.

## Program

See [lab11.S](lab11.S):

```asm
lui  x4, 0x1
addi x1, x0, 5
addi x2, x0, 7
.word 0x0020818b        # custom-0: x3 = x1 + x2 + 1
sw   x3, 0(x4)          # expected 13
addi x5, x3, 1
sw   x5, 4(x4)          # expected 14
park: jal x0, park
```

The exact custom instruction has `opcode=0x0b`, `rs1=x1`, `rs2=x2`, and `rd=x3`. It is deliberately decoded only for this example; other unrecognized instructions are not claimed by the PCPI unit.

## PCPI signals

| Signal | Direction from CPU | Function |
| --- | --- | --- |
| `pcpi_valid` | Output | Presents an unsupported instruction to the external unit |
| `pcpi_insn` | Output | Raw instruction encoding |
| `pcpi_rs1 / pcpi_rs2` | Output | Source operand values |
| `pcpi_wait` | Input | External unit requests more time; prevents PCPI timeout |
| `pcpi_ready` | Input | Result operation is complete |
| `pcpi_wr` | Input | Write result to instruction's destination register |
| `pcpi_rd` | Input | Returned 32-bit result |

The PCPI demo holds `wait` while counting three internal delay ticks, then presents `ready=1`, `wr=1`, and `rd=13` together. The CPU uses the destination encoded in the instruction (`x3`). The subsequent regular `addi` demonstrates that the result actually reached x3.

The PicoRV32 documentation warns that without `pcpi_wait`/acknowledgment, unsupported instructions can cause an illegal-instruction trap after a timeout. Here `pcpi_wait` remains asserted while the unit is busy.

## Run on Mac mini

```sh
git pull
make test LAB=lab11
make wave LAB=lab11
make disasm LAB=lab11
cat build/bus.trace
```

Expected decisive lines:

```text
STORE 0 addr=00001000 data=0000000d
STORE 1 addr=00001004 data=0000000e
PASS: Lab11 PCPI custom op result=13,14 cycles=...
```

The testbench checks both stores, the source operands and the custom instruction encoding during a `pcpi_ready && pcpi_wr` handshake, plus the observation of `pcpi_wait`. `trap` or timeout is a failure.

For waveform study, inspect `pcpi_valid`, `pcpi_insn`, `pcpi_rs1`, `pcpi_rs2`, `pcpi_wait`, `pcpi_ready`, `pcpi_wr`, `pcpi_rd`, and the usual memory bus signals. The human-readable `build/bus.trace` shows memory transactions, **not** internal PCPI handshakes.

## Questions

1. Why does PicoRV32 send an unrecognized instruction to PCPI rather than immediately trapping?
2. Why does `pcpi_wait` matter when an operation lasts several cycles?
3. What is the difference between `pcpi_ready` and `pcpi_wr`?
4. Where does the CPU obtain the destination register number?
5. How is PCPI different from a memory-mapped coprocessor?

## Completion

**PASS — Mac mini functional validation completed (2026-10-14).**

```text
STORE 0 addr=00001000 data=0000000d
STORE 1 addr=00001004 data=0000000e
PASS: Lab11 PCPI custom op result=13,14 cycles=42
```

`make wave LAB=lab11` also passed and generated `build/lab11.vcd`. The self-checking testbench observed the custom instruction's source operands, PCPI wait, ready/writeback result and final memory stores. The VCD was visually inspected and the PCPI handshake was observed.


**CLOSED — 2026-10-14.** Functional PASS (42 cycles), waveform generated and inspected; no further Lab11 work planned.

**Next:** Skip Lab12 and proceed directly to Lab13 (C compiler and ABI), per the project roadmap.

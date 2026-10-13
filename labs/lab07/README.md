# Lab07 — CPU Cycles vs Retired Instructions

## Goal

Separate **ISA instructions**, **PicoRV32 microarchitectural latency**, and **simulation elapsed time**. PicoRV32 has configurable `cycle` and `instret` counters; this experiment reads them around a short counted loop.

## Program

See [lab07.S](lab07.S). Its loop increments x1 four times, from 1 to 5, using an `addi`, another `addi`, and a `bne` per iteration. Two counter snapshots bracket the work:

```asm
rdcycle   x10
rdinstret x11
# ... loop ...
rdcycle   x12
rdinstret x13
sub x14,x12,x10
sub x15,x13,x11
```

The source encodes these four counter reads as `.word` CSR instructions for compatibility with a bare `rv32i` assembly target. Decode them with `objdump` (the counter read instructions are not arithmetic flag accesses). No additional CPU module or standard machine-mode CSR implementation is added.

Store results:
- `0x1000`: final x1 = 5
- `0x1004`: hardware cycle count difference
- `0x1008`: retired instruction count difference

The testbench checks x1=5, bounded nonzero deltas, and cycles greater than instructions. The precise counter deltas should be observed rather than hardcoded, because the placement of reads and memory latency affect them.

## Run

```sh
git pull
make test LAB=lab07 WAIT=0
make disasm LAB=lab07
cat build/bus.trace
make test LAB=lab07 WAIT=3
make wave LAB=lab07 WAIT=3
```

For a fair comparison, record the three numbers printed by each PASS: `cycle_delta`, `instret_delta`, and `simulation_cycles`.

### Interpretation

- **cycle_delta**: the difference between two hardware counter reads; includes stalls and measurement overhead within the interval
- **instret_delta**: retired instructions between two readings, including the effect of where exactly the snapshots occur
- **cycle_delta / instret_delta**: an *interval-average* CPI approximation, not per-opcode CPI
- **simulation_cycles**: the testbench's total elapsed cycles after reset release to its completion condition, including setup, stores and checks outside the measured interval
- **IFETCH rows**: memory bus reads, not proof of instruction retirement

The current RAM model has a registered baseline response. `WAIT=N` adds N more clock cycles before asserting `mem_ready`.

## Questions

1. Why can two CPUs running the same RV32I instructions have very different CPI?
2. Why is `simulation_cycles` greater than the measured `cycle_delta`?
3. What is the difference between `instret` and counting `IFETCH` lines?
4. What happens to `cycle_delta` and `instret_delta` when RAM latency increases?
5. Why is this measurement not sufficient to attribute an exact cycle cost to each ALU instruction or branch?

## Completion

Mac mini execution pending. Record the observed counter values and any surprising behavior here, not in the root README.

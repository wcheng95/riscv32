# Lab06 — PicoRV32 Native Memory Handshake

## Goal

Study the CPU's native bus (`mem_valid` / `mem_ready`) and observe how adding RAM wait states affects elapsed execution cycles. The CPU RTL is unchanged; only the shared `tbench/ram.v` response latency is configurable.

## Firmware

Source: [lab06.S](lab06.S).

```asm
lui  x4, 0x1
addi x5, x0, 42
sw   x5, 0(x4)       # RAM[0x1000] = 42
lw   x6, 0(x4)       # read it back
addi x6, x6, 1
sw   x6, 4(x4)       # RAM[0x1004] = 43
park: jal x0, park
```

Expected stores: `0x1000 = 0x0000002a` and `0x1004 = 0x0000002b`.

## Interface rules

- The CPU initiates a request by asserting `mem_valid`; transaction address, direction, data and byte strobes must remain stable until completion.
- The RAM asserts `mem_ready` to complete the transfer. The handshake is sampled on a rising clock edge with both signals high.
- An instruction fetch uses `mem_instr=1`; a data load uses zero `mem_wstrb`; a store uses nonzero byte strobes.
- Our RAM has a registered response in its baseline configuration. Setting `WAIT` inserts **additional** cycles before `mem_ready` is asserted. The pre-existing baseline is not zero-latency.

## Run on Mac mini

```sh
git pull
make test LAB=lab06 WAIT=0
cat build/bus.trace
make wave LAB=lab06 WAIT=0

make test LAB=lab06 WAIT=3
cat build/bus.trace
make wave LAB=lab06 WAIT=3
```

The VCD, `build/lab06.vcd`, contains `mem_valid`, `mem_ready`, `mem_addr`, `mem_wstrb` and the RAM's `wait_count`. The human-readable `build/bus.trace` contains only **completed transfers**, not individual stall cycles. Both output files are overwritten on subsequent runs.

To compare waveforms, copy each VCD to a distinct filename under `build/` before the next run.

## What to inspect

1. Compare elapsed PASS cycle counts for `WAIT=0` and `WAIT=3`.
2. Verify that `mem_valid` stays asserted during extra waiting.
3. Verify that `mem_addr`, `mem_wstrb` and `mem_wdata` remain stable until handshake completion.
4. Observe both instruction fetches and data accesses; all use the same native interface.
5. Confirm the store data and address remain unchanged regardless of RAM latency.

## Questions

1. Does `mem_valid=1` alone mean a transaction has completed?
2. What precise event completes the memory transfer?
3. Why can increasing memory wait states change execution time without changing the firmware's arithmetic results?
4. Why can the text trace not directly reveal the number of stalled cycles?
5. How is the native bus different from the 68000's DTACK handshake?

## Completion

Implementation committed. Mac mini verification of both wait-state configurations and their measured cycle counts is pending; record observations here, not in the root README.

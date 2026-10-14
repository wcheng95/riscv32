# Lab08 — PicoRV32 Register-File Read Ports

## Goal

Compare the **same RV32I program** on two builds of the unchanged PicoRV32 core: two register-file read ports versus one. The ISA and program results remain identical; implementation timing can differ.

The build selects PicoRV32's RTL parameter `ENABLE_REGS_DUALPORT`:
- `REGS=1` (default): dual read ports, allowing both source operands to be read together
- `REGS=0`: single read port, potentially requiring an additional cycle for instructions with two register operands

This is a **compile/elaboration parameter**, not a runtime switch. Each variant gets a separate VVP binary under `build/`. Do not confuse the CPU's register-file ports with its native memory bus.

## Firmware

See [lab08.S](lab08.S). A compact sequence exercises two-source operations (`add`, `sub`, `sll`, `xor`) and stores both results.

```asm
lui  x4, 0x1
addi x1, x0, 6
addi x2, x0, 11
add  x3, x1, x2
sub  x5, x2, x1
sll  x6, x5, x1
xor  x7, x3, x6
sw   x3, 0(x4)
sw   x7, 4(x4)
park: jal x0, park
```

Expected `0x1000 = 17` and `0x1004 = 337 (0x151)` for **both** configurations.

## Run on Mac mini

```sh
git pull
make test LAB=lab08 REGS=1
make test LAB=lab08 REGS=0
make disasm LAB=lab08
```

Compare the `simulation_cycles` in the two PASS messages. Both must produce identical stores. Keep `WAIT=0` in both runs.

To observe memory handshakes:

```sh
make wave LAB=lab08 REGS=1
cp build/lab08.vcd build/lab08_dual.vcd
make wave LAB=lab08 REGS=0
cp build/lab08.vcd build/lab08_single.vcd
```

The standard bus trace `build/bus.trace` is overwritten each run. The trace shows *completed memory transactions*, not internal register-file reads; examine waveforms and elapsed cycles for the performance difference.

## Questions

1. Why does reducing register-file read ports potentially save hardware resources?
2. Which instructions need two source-register operands? Which use one?
3. Why can the same ISA and program produce different cycle counts?
4. Is `ENABLE_REGS_DUALPORT` an ISA property, an RTL build choice or a CPU input pin?
5. Why shouldn't `IFETCH` count be used as the number of register-file reads?

## Completion

Implemented, pending two Mac mini simulation results. Record measurements here and keep the root README unchanged.

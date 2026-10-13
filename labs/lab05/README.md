# Lab05 — Branches, JAL and JALR

## Goal

Observe signed and unsigned branches, PC-relative `jal`, and indirect `jalr` in the unchanged PicoRV32 CPU. All results are checked through architectural stores, not internal registers.

## Program

See [lab05.S](lab05.S). There are four intentionally **forbidden** stores to `0x1010`: they must never execute. The four permitted writes go to `0x1000`, `0x1004`, `0x1008`, and `0x100c`.

The interesting instructions:

- `blt x1,x2,signed_ok` is taken because signed −1 is less than 1.
- `bltu x1,x2,bad` is *not* taken because unsigned 0xffffffff is greater than 1.
- `bgeu x1,x2,unsigned_ok` is taken.
- `jal x6,after_j` at PC `0x20` stores link address `0x24`, and jumps to `0x28`.
- `auipc x8,0` at `0x2c` creates a PC-relative base; `addi x8,x8,17` makes it `0x3d`.
- `jalr x9,0(x8)` at PC `0x34` clears target bit 0, jumps to `0x3c`, and stores link `0x38` in x9.

Unlike branch and JAL, JALR forms its target using a register and a signed 12-bit immediate, then clears bit 0.

## Expected stores

| Address | Value | Meaning |
| --- | --- | --- |
| `0x1000` | `00000024` | JAL link = PC+4 |
| `0x1004` | `00000038` | JALR link = PC+4 |
| `0x1008` | `ffffffff` | x1 preserved as −1 |
| `0x100c` | `00000001` | x2 preserved as +1 |

Any store to `0x1010` fails the self-checking testbench. The completion condition is the fourth expected store; a trap or timeout also fails.

## Run on Mac mini

```sh
git pull
make test LAB=lab05
make disasm LAB=lab05
cat build/bus.trace
make wave LAB=lab05
```

The bus trace is generated automatically under `build/bus.trace`. Observe the instruction fetch sequence before and after branches; a bus `IFETCH` is not proof of architectural retirement.

## Questions

1. Why does `blt` take the first branch but `bltu` not take the second?
2. Which PC does `jal` use to form the link address?
3. Why is the `jalr` target `0x3c`, not `0x3d`?
4. Which instructions use PC-relative targets, and which use a register base?
5. Does a fetched but skipped `sw` necessarily write to memory?

## Completion

**PASS — Mac mini functional validation complete.** Four expected stores and no forbidden store; 81 testbench cycles.

## Observed result

```text
STORE 0 addr=00001000 data=00000024
STORE 1 addr=00001004 data=00000038
STORE 2 addr=00001008 data=ffffffff
STORE 3 addr=0000100c data=00000001
PASS: Lab05 branches JAL JALR cycles=81
```

The disassembly confirms `blt` at 0x0c, `bltu` at 0x14, `bgeu` at 0x18, `jal` at 0x20, `auipc` at 0x2c and `jalr` at 0x34.

## Observations from the bus trace

- The CPU fetched the skipped store at 0x10 after the taken branch at 0x0c, and the skipped store at 0x1c after the branch at 0x18; neither performed a memory write.
- `jal` from 0x20 transferred to 0x28, preserving link 0x24.
- `auipc` at 0x2c and `addi` at 0x30 formed target `0x3d`; `jalr` at 0x34 cleared bit 0 and fetched from 0x3c. It preserved link 0x38.
- Last accepted store was at trace cycle 80; testbench finished on cycle 81.

These are native-bus observations, not a complete instruction-retirement trace. Record future timing analysis in the dedicated timing lab.


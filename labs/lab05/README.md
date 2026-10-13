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

Implementation committed; functional verification on Mac mini and measured cycle count pending. Keep results here, not in the root README.

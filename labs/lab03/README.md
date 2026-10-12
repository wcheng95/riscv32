# Lab03 — ALU Shifts and Signedness

## Goal

Study RV32I ALU operations using exactly the same 32-bit register patterns interpreted in two ways: logical versus arithmetic shifts, and unsigned versus signed comparisons. No arithmetic flags are set.

## Program

Source: [lab03.S](lab03.S).

```asm
addi x1, x0, -1       # x1 = 0xffffffff
addi x2, x0, 1
srli x3, x1, 1        # zero-filled logical shift
srai x5, x1, 1        # sign-filled arithmetic shift
sltu x6, x2, x1       # unsigned 1 < 0xffffffff
slt  x7, x1, x2       # signed -1 < 1
lui  x4, 0x1
sw   x3, 0(x4)
sw   x5, 4(x4)
sw   x6, 8(x4)
sw   x7, 12(x4)
park: jal x0, park
```

## Expected RAM writes

| Address | Value | Observation |
|---|---|---|
| `0x1000` | `0x7fffffff` | `srli` zero-fills |
| `0x1004` | `0xffffffff` | `srai` replicates sign bit |
| `0x1008` | `0x00000001` | `sltu`: 1 less than 4294967295 |
| `0x100c` | `0x00000001` | `slt`: −1 less than 1 |

Both comparisons return 1, but their operand order differs. To see the contrast directly, mentally evaluate `sltu x6,x1,x2` (0) versus `slt x7,x1,x2` (1).

## Build and inspect on Mac mini

```sh
git pull
make test LAB=lab03
make disasm LAB=lab03
cat build/bus.trace
make wave LAB=lab03
```

Tracing is enabled by default and remains owned by the single native-bus monitor. The shared machine uses the unchanged PicoRV32 RTL.

## Questions

1. Why does `srli` produce `0x7fffffff`, but `srai` produces `0xffffffff`?
2. Does any ALU instruction update a CCR-like arithmetic flag register?
3. Why is the same bit pattern `0xffffffff` either −1 or 4294967295?
4. Which fields of the instruction distinguish `srli` from `srai`?
5. Which parts of this lab can you verify from the bus trace alone, and which require disassembly?

## Completion

Implementation committed; Mac mini functional verification and observed cycle count pending. Record actual results here, not in the root README.

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

**PASS — Mac mini functional verification complete.** All four expected stores matched; 62 testbench cycles elapsed to the completion check.

## Observed Mac mini output (2026-10-11)

```text
STORE 0 addr=00001000 data=7fffffff
STORE 1 addr=00001004 data=ffffffff
STORE 2 addr=00001008 data=00000001
STORE 3 addr=0000100c data=00000001
PASS: Lab03 shifts and signedness cycles=62
```

The disassembly verifies:
- `srli` at 0x08: `0010d193`
- `srai` at 0x0c: `4010d293`
- `sltu` at 0x10: `00113333`
- `slt` at 0x14: `0020a3b3`

Note the `0x40000000` difference between the two shift encodings: `srai` selects the arithmetic right shift via its upper immediate bits.

## Bus trace observations

```text
11 IFETCH 00000008 0010d193
15 IFETCH 0000000c 4010d293
20 IFETCH 00000010 00113333
25 IFETCH 00000014 0020a3b3
40 WRITE  00001000 7fffffff 1111
47 WRITE  00001004 ffffffff 1111
54 WRITE  00001008 00000001 1111
61 WRITE  0000100c 00000001 1111
```

The fetch completion cycle gaps vary (e.g. 4, 5, 5), but this bus trace is **not** an instruction-retirement trace. Timing details and per-instruction CPI should be examined in the dedicated timing lab. The last store and park-instruction fetch occur before the testbench terminates.


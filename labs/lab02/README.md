# Lab02 — RV32I Instruction Formats

## Goal

Decode one representative instruction from each RV32I encoding format: **R, I, S, B, U, J**. See [lab02.S](lab02.S). Observe the difference between *instruction bits*, *immediate values*, and *effective addresses*.

## Instruction formats (bits 31 down to 0)

```text
R: funct7 | rs2 | rs1 | funct3 | rd  | opcode
I: imm[11:0]    | rs1 | funct3 | rd  | opcode
S: imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode
B: imm[12|10:5] | rs2 | rs1 | funct3 | imm[4:1|11] | opcode
U: imm[31:12]                         | rd | opcode
J: imm[20|10:1|11|19:12]             | rd | opcode
```

B and J immediates are split across instruction fields. Their byte offsets have an implicit zero bit 0 and are sign-extended. B-type can represent signed even offsets from -4096 to +4094 bytes; J-type from -1048576 to +1048574 bytes. RISC-V 32-bit instructions are 4 bytes, but B/J encoding offsets use 2-byte units (to accommodate compressed instruction targets).

## Program and expected effects

| PC | Instruction | Type | Meaning |
| --- | --- | --- | --- |
| 0x00 | `addi x1,x0,5` | I | x1 = 5 |
| 0x04 | `addi x2,x0,7` | I | x2 = 7 |
| 0x08 | `add x3,x1,x2` | R | x3 = 12 |
| 0x0c | `lui x4,0x1` | U | x4 = 0x1000 |
| 0x10 | `auipc x5,0` | U | x5 = 0x10 |
| 0x14 | `beq x3,x0,wrong` | B | Not taken |
| 0x18 | `beq x3,x3,after_b` | B | Taken; skip 0x1c |
| 0x1c | `sw x0,12(x4)` | S | Must be skipped |
| 0x20 | `sw x3,0(x4)` | S | Write 12 |
| 0x24 | `jal x6,after_j` | J | Jump; x6 = 0x28 |
| 0x28 | `sw x0,12(x4)` | S | Must be skipped |
| 0x2c | `sw x6,4(x4)` | S | Write 0x28 |
| 0x30 | `sw x5,8(x4)` | S | Write 0x10 |
| 0x34 | `jal x0,park` | J | Infinite park loop |

The testbench checks stores at `0x1000` = `0x0c`, `0x1004` = `0x28`, and `0x1008` = `0x10`. An unexpected store to `0x100c` fails the test.

## Build and inspect (Mac mini)

```sh
make test LAB=lab02
make disasm LAB=lab02
cat build/bus.trace
make wave LAB=lab02
```

The assembler uses `-march=rv32i -mabi=ilp32 -mno-relax`; the linker locates code at PC=0. The testbench uses the shared CPU/RAM/bus monitor. All generated files remain under `build/`.

## Decoding exercise

Find `add x3,x1,x2` in `make disasm LAB=lab02`. Decode its 32-bit instruction word:

- bits [6:0] opcode = `0110011` (R-type integer register)
- bits [11:7] rd = 3
- bits [14:12] funct3 = 0
- bits [19:15] rs1 = 1
- bits [24:20] rs2 = 2
- bits [31:25] funct7 = 0

Next decode `beq` and `jal`: notice the offsets are PC-relative, not absolute and not relative to PC+4. Compare the instruction-fetch addresses to the disassembly.

## Questions

1. Why does each instruction always contain a 7-bit opcode at bits [6:0]?
2. Why are store and branch immediate bits split across different fields?
3. Why does `auipc x5,0` produce 0x10 in this program?
4. What does `jal x6,after_j` write to x6, and why?
5. Does an `IFETCH` entry in the bus trace by itself prove retirement?

## Completion

Pending functional test on the Mac mini. Record observed cycles and bus behavior here; do not update the root README with progress.

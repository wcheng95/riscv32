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

**PASS — Mac mini functional validation complete.** Observed 60 testbench cycles.

## Observed Mac mini result (2026-10-11)

```text
STORE 0 addr=00001000 data=0000000c
STORE 1 addr=00001004 data=00000028
STORE 2 addr=00001008 data=00000010
PASS: Lab02 R/I/S/B/U/J formats cycles=60
```

The generated ELF is `elf32-littleriscv`. The disassembly confirms `auipc` at 0x10, a taken `beq` at 0x18, and a `jal` at 0x24 that saves 0x28 as its link address.

### Bus trace observation

```text
27  IFETCH  00000018    00318463
31  IFETCH  0000001c    00022623
34  IFETCH  00000020    00322023
41  WRITE   00001000    0000000c    1111
```

Although the branch at 0x18 is taken to 0x20, the CPU's memory interface reports a fetch from 0x1c. **A bus fetch does not guarantee the fetched instruction is executed or retired.** No write to 0x100c occurred. This is worth examining in the later execution-timing/control-flow lab.

The trace is a memory-bus record, not a formal retirement trace. Source files and upstream RTL remain unchanged.

## Review notes: answers to Lab02 questions

1. **Opcode:** bits [6:0] consistently hold the *major opcode* (instruction class); `funct3` and `funct7` can distinguish specific operations. A fixed field position simplifies decode.
2. **Split immediates:** preserving the bit locations of `rs1`, `rs2`, and `funct3` simplifies register decoding. B-type rearranges the S-type immediate positions to encode an offset with implicit bit 0 = 0, avoiding a separate immediate left-shift in hardware.
3. **AUIPC:** `rd = PC + (imm20 << 12)`; here the AUIPC instruction itself is at PC = `0x10`, and the immediate is zero, so `x5 = 0x10`.
4. **JAL:** stores **PC + 4**, not the current PC, into `rd`. At PC `0x24`, `x6 = 0x28`; execution continues at target `0x2c`.
5. **Fetch versus retirement:** a memory-bus `IFETCH` does not prove execution/retirement. At `0x1c`, the skipped store is fetched but does not generate a write.

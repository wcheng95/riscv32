# PicoRV32 RTL Reading Notes

This is a relaxed side track for reading the upstream PicoRV32 RTL used by this repository.

The goal is **understanding**, not finishing a syllabus and not modifying the core. The main `riscv32` labs remain the structured path; this document is a source-reading notebook we can return to whenever CPU RTL is interesting.

The repository carries PicoRV32 from upstream commit `ef203c2b0a3fb793280f5114941416c425c5b461`. Keep `picorv32/picorv32.v` unmodified and record observations here.

The configured study core is **RV32I**: compressed instructions, multiply/divide and PCPI are disabled in the shared testbench.

## Method

Use the RV32I instruction set itself as the reading checklist.

For each instruction, do not mark it checked merely because a test program executes it. A useful RTL check should identify, as applicable:

1. decode condition,
2. immediate/source-register path,
3. ALU / branch / memory action,
4. destination-register writeback or PC update,
5. any PicoRV32-specific multi-cycle/control behavior.

Keep each investigation small. Similar instructions may share most of the same RTL, but each row should still be accounted for.

## RV32I instruction checklist

This table intentionally contains **only real RV32I instructions**.

Excluded:
- pseudoinstructions such as `nop`, `mv`, `li`, `ret`
- M-extension multiply/divide instructions
- C compressed instructions
- CSR instructions from the separate Zicsr extension
- `FENCE.I`, which belongs to the separate Zifencei extension

Status:
- `TODO` — not yet traced
- `CHECKED` — decode through architectural effect understood
- `NOTE` — behavior understood but deserves a follow-up detail

| # | Instruction | Class | Architectural effect | RTL status | RTL notes |
|---:|---|---|---|---|---|
| 1 | `LUI rd, imm` | U | `rd = imm << 12` | TODO | |
| 2 | `AUIPC rd, imm` | U | `rd = pc + (imm << 12)` | TODO | |
| 3 | `JAL rd, off` | J | `rd = pc+4; pc += off` | TODO | |
| 4 | `JALR rd, rs1, imm` | I | `rd = pc+4; pc = (rs1+imm) & ~1` | TODO | |
| 5 | `BEQ rs1, rs2, off` | B | branch if `rs1 == rs2` | TODO | |
| 6 | `BNE rs1, rs2, off` | B | branch if `rs1 != rs2` | TODO | |
| 7 | `BLT rs1, rs2, off` | B | signed `rs1 < rs2` | TODO | |
| 8 | `BGE rs1, rs2, off` | B | signed `rs1 >= rs2` | TODO | |
| 9 | `BLTU rs1, rs2, off` | B | unsigned `rs1 < rs2` | TODO | |
| 10 | `BGEU rs1, rs2, off` | B | unsigned `rs1 >= rs2` | TODO | |
| 11 | `LB rd, imm(rs1)` | I/load | load byte, sign-extend | TODO | |
| 12 | `LH rd, imm(rs1)` | I/load | load halfword, sign-extend | TODO | |
| 13 | `LW rd, imm(rs1)` | I/load | load word | TODO | |
| 14 | `LBU rd, imm(rs1)` | I/load | load byte, zero-extend | TODO | |
| 15 | `LHU rd, imm(rs1)` | I/load | load halfword, zero-extend | TODO | |
| 16 | `SB rs2, imm(rs1)` | S/store | store low byte | TODO | |
| 17 | `SH rs2, imm(rs1)` | S/store | store low halfword | TODO | |
| 18 | `SW rs2, imm(rs1)` | S/store | store word | TODO | |
| 19 | `ADDI rd, rs1, imm` | I/ALU | `rd = rs1 + imm` | TODO | |
| 20 | `SLTI rd, rs1, imm` | I/ALU | signed less-than immediate | TODO | |
| 21 | `SLTIU rd, rs1, imm` | I/ALU | unsigned less-than immediate | TODO | |
| 22 | `XORI rd, rs1, imm` | I/ALU | bitwise XOR immediate | TODO | |
| 23 | `ORI rd, rs1, imm` | I/ALU | bitwise OR immediate | TODO | |
| 24 | `ANDI rd, rs1, imm` | I/ALU | bitwise AND immediate | TODO | |
| 25 | `SLLI rd, rs1, shamt` | I/shift | logical left shift | TODO | |
| 26 | `SRLI rd, rs1, shamt` | I/shift | logical right shift | TODO | |
| 27 | `SRAI rd, rs1, shamt` | I/shift | arithmetic right shift | TODO | |
| 28 | `ADD rd, rs1, rs2` | R | `rd = rs1 + rs2` | TODO | |
| 29 | `SUB rd, rs1, rs2` | R | `rd = rs1 - rs2` | TODO | |
| 30 | `SLL rd, rs1, rs2` | R | logical left shift | TODO | |
| 31 | `SLT rd, rs1, rs2` | R | signed less-than | TODO | |
| 32 | `SLTU rd, rs1, rs2` | R | unsigned less-than | TODO | |
| 33 | `XOR rd, rs1, rs2` | R | bitwise XOR | TODO | |
| 34 | `SRL rd, rs1, rs2` | R | logical right shift | TODO | |
| 35 | `SRA rd, rs1, rs2` | R | arithmetic right shift | TODO | |
| 36 | `OR rd, rs1, rs2` | R | bitwise OR | TODO | |
| 37 | `AND rd, rs1, rs2` | R | bitwise AND | TODO | |
| 38 | `FENCE` | memory ordering | order memory/device accesses | TODO | |
| 39 | `ECALL` | SYSTEM | environment call | TODO | |
| 40 | `EBREAK` | SYSTEM | breakpoint request | TODO | |

## Source map

A useful first-pass map of `picorv32.v`:

1. **Configuration and top-level interface**
   - feature parameters
   - native memory interface
   - look-ahead memory interface
   - PCPI coprocessor interface
   - optional IRQ, trace and RVFI interfaces

2. **Architectural and internal state**
   - `reg_pc`, `reg_next_pc`
   - operand/result registers such as `reg_op1`, `reg_op2`, `reg_out`
   - cycle/instruction counters
   - register file `cpuregs`

3. **Instruction fetch and memory sequencing**
   - instruction reads versus data reads/writes
   - `mem_valid` / `mem_ready` handshake
   - address/data/write-strobe generation
   - look-ahead signals

4. **Decode**
   - instruction fields and immediate construction
   - instruction-class decode
   - illegal-instruction handling

5. **Execution control**
   - CPU state machine
   - operand selection
   - ALU operations
   - branches and jumps
   - shifts and multi-cycle options

6. **Register-file read/write path**
   - source register selection
   - single-port versus dual-port configuration
   - writeback
   - x0 behavior

7. **Loads and stores**
   - byte/halfword/word access
   - sign/zero extension
   - write strobes
   - alignment checks

8. **Other base behavior**
   - `FENCE`
   - `ECALL` / `EBREAK`
   - counters and trap behavior where relevant

## Per-instruction note format

When a row is checked, add a short note below the table if useful:

```text
Instruction
ADD

Decode
Which decode signal/condition identifies it?

Operands
Where do rs1 and rs2 come from?

Execute
Which ALU/control expression performs the operation?

Architectural effect
Where/how is rd written or the PC/memory state changed?

PicoRV32 detail
Anything implementation-specific worth remembering?
```

The notebook should grow from actual RTL questions rather than attempting to document every line of PicoRV32.

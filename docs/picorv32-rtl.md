# PicoRV32 RTL Reading Notes

This is a relaxed side track for reading the upstream PicoRV32 RTL used by this repository.

The goal is **understanding**, not finishing a syllabus and not modifying the core. The main `riscv32` labs remain the structured path; this document is a source-reading notebook we can return to whenever CPU RTL is interesting.

The repository carries PicoRV32 from upstream commit `ef203c2b0a3fb793280f5114941416c425c5b461`. Keep `picorv32/picorv32.v` unmodified and record observations here.

The configured study core is **RV32I**: compressed instructions, multiply/divide and PCPI are disabled in the shared testbench.

## Study RTL views

- [Clean fixed-RV32I PicoRV32](rtl/picorv32-rv32i-clean.v) — **primary walkthrough file from S04 onward**
- [Line-preserving RV32I study RTL](rtl/picorv32-rv32i-study.v) — audit/reference snapshot
- [RTL view/validation notes](rtl/README.md)
- [Independent RV32I core](../rtl/rv32_core.v) — future own-core baseline; defer detailed study until PicoRV32 is understood

The line-preserving view was useful for S01–S03 because source line numbers matched upstream exactly. Starting with the memory-interface study, use the cleaned fixed-RV32I core so disabled C/M/PCPI/IRQ/counter/trace paths no longer consume attention.

Phase A was validated cycle-for-cycle against fixed-configuration upstream PicoRV32 on Labs 00–06, including inserted memory wait states. Phase B is intentionally simpler and was validated architecturally through the strict-RV32I regression; it is not expected to preserve PicoRV32 timing.

## Session progress

### S01 — module parameters — DONE

**Study RTL:** through line 88  
**Next:** line 89, module port list

What we settled:

- PicoRV32 configuration values here are Verilog **parameters**: elaboration/build-time constants, not runtime pins.
- `INSN` means *instruction*; `CATCH_ILLINSN=1` catches unsupported/illegal instruction encodings and routes them toward trap handling.
- For the stripped study RTL, `ENABLE_COUNTERS=0`; cycle/instret counters are outside the strict RV32I study scope.
- With `ENABLE_IRQ=0`, `MASKED_IRQ`, `LATCHED_IRQ`, and `PROGADDR_IRQ` are IRQ-related configuration and not part of our RV32I path.
- `PROGADDR_RESET` supplies the reset PC.
- `STACKADDR` optionally supplies the initial value of `x2` / `sp`. The default `32'hffff_ffff` is a sentinel meaning PicoRV32 does not initialize `sp` from this parameter.
- RISC-V has no special stack engine: `sp` is architectural register `x2`, used by software convention with ordinary integer arithmetic and loads/stores.
- The standard stack grows toward lower addresses. A function allocates a frame by subtracting from `sp` and releases it by restoring `sp`.
- Standard RISC-V ABI stack alignment is 16 bytes, so a compliant `sp` has `sp[3:0] == 4'b0000`. Alignment alone does not make an address usable; the stack must also have valid writable memory below it.
- `STACKADDR` is mainly startup convenience: when supplied, hardware can initialize `sp` so startup software does not need to do so. The compiler generally only assumes that `sp` is valid when compiled code begins.

### S02 — module ports and local parameters — DONE

**Study RTL:** lines 89–173  
**Next:** line 174

What we settled:

- The minimal RV32I implementation interface keeps `clk`, `resetn`, `trap`, and the normal memory bus signals: `mem_valid`, `mem_instr`, `mem_ready`, `mem_addr`, `mem_wdata`, `mem_wstrb`, and `mem_rdata`.
- The look-ahead memory interface `mem_la_*` is a PicoRV32 optimization/interface convenience and is not required for the minimal implementation.
- PCPI, IRQ/EOI, and trace ports are outside our stripped RV32I implementation scope.
- `trap` is the core's terminal/fault indication in our minimal design.
- Among the local parameters in this section, the two that matter to our implementation are:
  - `regfile_size = 32`
  - `regindex_bits = 5`
- The remaining IRQ/trace/PCPI local parameters can be ignored for our RV32I reconstruction.

### S03 — core datapath state and PCPI boundary — DONE

**Study RTL:** lines 174–348  
**Next:** line 349, memory interface

What we settled:

- For this study, skip `dbg_*`, `pcpi_*`, and `irq_*` signals unless one directly affects the RV32I path.
- Core datapath/state signals introduced here:
  - `reg_pc` — current instruction PC.
  - `reg_next_pc` — next instruction address carried across cycles.
  - `reg_op1` — latched first operand, usually `rs1`.
  - `reg_op2` — latched second operand, either `rs2` or an immediate depending on the instruction.
  - `reg_out` — general result/temporary register used across FSM states.
  - `reg_sh` — shift count/state for the iterative shifter.
  - `next_insn_opcode` — fetched instruction word headed toward decode.
  - `next_pc` — combinational next-fetch address, defined later from control state.
  - `cpuregs` — built-in integer register file; in our configuration this is 32 × 32-bit.
- `count_cycle` and `count_instr` remain in the source but are inactive in the study configuration because `ENABLE_COUNTERS=0`.
- The `integer i` and `initial` register-file initialization block are irrelevant with `REGS_INIT_ZERO=0`.
- `empty_statement` is only a helper for the disabled/non-formal assert macro and is not CPU functionality.
- Lines 255–348 are internal PCPI plumbing. With PCPI/M/DIV disabled, this entire region is outside the RV32I implementation path and can be skipped.

## Block diagram

![PicoRV32 RV32I block diagram](picorv32_diagram.png)

The diagram is derived from the RTL and shows the current RV32I study configuration. It is a living architectural view: as the source-order walkthrough exposes more precise boundaries or control relationships, update the SVG rather than treating it as an upstream specification.

## Goal: reconstruct an implementable RV32I core

Read `picorv32.v` **in RTL source order** and turn it into a compact implementation specification.

The intended end state is that these notes contain enough structure and behavior to write a small RV32I implementation without having to rediscover how the core fits together.

This is not a line-by-line translation of PicoRV32. For each RTL region, extract:

1. **Purpose** — what hardware responsibility this block owns.
2. **State** — registers/state variables that must survive a clock edge.
3. **Inputs and outputs** — signals entering/leaving the block.
4. **Combinational rules** — decisions that can be expressed without stored state.
5. **Sequential rules** — what changes on each relevant clock edge.
6. **Control transitions** — where the CPU/memory state machine goes next.
7. **Instruction coverage** — which RV32I instructions depend on this block.
8. **Implementation sketch** — short pseudocode or equations sufficient to rebuild the behavior.

We follow physical RTL order even when that is not the easiest pedagogical order. This lets the document become a companion map to the actual source.

Our implementation scope is the configuration used by the shared testbench:

```text
RV32I
COMPRESSED_ISA = 0
ENABLE_MUL     = 0
ENABLE_DIV     = 0
ENABLE_PCPI    = 0
ENABLE_IRQ     = 0
```

When the upstream RTL reaches C, M, PCPI, IRQ, trace, or formal-only machinery, record its boundary and skip the internal details unless they affect the RV32I path.

The RV32I instruction table below is therefore a **coverage index**, not the reading order. An instruction becomes `CHECKED` only when the source-ordered walkthrough has exposed its complete path from decode to architectural effect.

## Next goal after PicoRV32: minimum FreeRTOS-capable MCU

Do **not** start this until the PicoRV32 RV32I core walkthrough is complete. The immediate goal remains understanding the existing core well enough to reconstruct it independently.

After that, use the reconstructed RV32I core as the base for a minimal standards-based RISC-V MCU capable of running FreeRTOS.

Target progression:

```text
understand PicoRV32 RV32I completely
        ↓
reconstruct own small RV32I core
        ↓
add Zicsr
        ↓
add minimal Machine-mode trap/interrupt support
        ↓
add timer interrupt
        ↓
run FreeRTOS
        ↓
add peripherals / accelerators incrementally
```

### Minimum architectural additions

Keep the first MCU intentionally small:

- **RV32I** base ISA.
- **Zicsr** CSR instructions.
- **Machine mode only**; no Supervisor/User mode requirement.
- Minimal Machine-mode CSRs needed by the FreeRTOS port:
  - `mstatus`
  - `mie`
  - `mip`
  - `mtvec`
  - `mepc`
  - `mcause`
  - `mscratch`
  - add `mtval` only when useful for cleaner exception reporting.
- **`MRET`** to return from traps/interrupts.
- **`ECALL`** handling for voluntary FreeRTOS task yield.
- One **periodic Machine-mode timer interrupt** for the FreeRTOS tick.
- Writable RAM for task stacks and the FreeRTOS heap.
- Program storage in ROM/flash/RAM.

Not required for the first FreeRTOS MCU:

- A extension / atomics for a single-core implementation.
- MMU.
- PMP.
- FPU.
- Vector extension.
- Multi-core support.
- Full CLINT if a simpler timer can provide the required Machine-mode tick interrupt.

### Minimal trap behavior

On interrupt or exception, the hardware should conceptually provide:

```text
mepc          ← interrupted/faulting PC
mcause        ← trap cause
mstatus.MPIE  ← mstatus.MIE
mstatus.MIE   ← 0
PC            ← mtvec
```

Software then saves/restores the remaining task context. `MRET` restores the Machine interrupt-enable state and resumes execution from `mepc`.

For an `ECALL`-based FreeRTOS yield, the trap handler must distinguish the environment-call cause, perform the scheduler/context-switch work, advance `mepc` past the `ECALL`, and return with `MRET`.

### Minimal timer

Start with a deliberately small timer block:

```text
free-running counter
        │
   compare register
        │
counter >= compare
        ↓
Machine timer interrupt
        ↓
FreeRTOS tick handler
```

A standards-compatible `mtime` / `mtimecmp` style interface is desirable, but the first implementation may use a simpler memory-mapped timer if the small FreeRTOS port layer is adapted cleanly.

### First FreeRTOS milestone

Keep the first software test smaller than MiniShell or any real application:

```text
Task A increments / reports A
Task B increments / reports B
periodic timer tick preempts them
explicit yield via ECALL works
context resumes correctly
```

Only after that baseline is stable should the MCU grow UART, GPIO, MiniShell, or accelerators.

### Development platform and project boundary

Do not build the software toolchain or a complete machine ecosystem from scratch.

Use existing, standard components:

```text
RISC-V GCC / binutils
        ↓
FreeRTOS + firmware
        ↓
QEMU RISC-V virt machine
        ↓
reference behavior / software bring-up
        ↓
our RV32I + Zicsr + M-mode RTL
        ↓
minimal compatible MCU peripherals
        ↓
FPGA
```

The compiler, assembler, linker, debugger and ABI are **not** part of this project. The CPU should run ordinary compiler-generated RISC-V code rather than requiring a custom compiler.

Use QEMU `virt` as the software/reference platform so we do not need to invent every board-level convention ourselves. Prove FreeRTOS and firmware behavior there first, then reproduce only the software-visible hardware that the RTL MCU actually needs.

Do **not** try to clone the complete QEMU `virt` machine in FPGA. Start with the minimum useful hardware:

```text
RV32I + Zicsr + M-mode CPU
            │
            ├── RAM
            ├── timer / software-interrupt block
            └── UART
```

Add PLIC, flash interfaces, GPIO or other peripherals only when a concrete requirement appears.

A useful validation target is to keep the same normal RISC-V software/toolchain path across:

```text
QEMU
  ↓
RTL simulation
  ↓
FPGA
```

The closer the firmware environment stays across those three targets, the less custom infrastructure we need to maintain.

### FPGA target

The MCU RTL is intended to run on FPGA after the software path has been validated in QEMU and RTL simulation.

The FPGA is the hardware learning/deployment target, not a reason to build a custom compiler, operating system, or board ecosystem. Keep hardware/software boundaries conventional wherever possible so effort stays concentrated on CPU architecture, interrupt/trap support, peripherals and accelerators.

### Accelerator direction

Future accelerators such as an LDPC decoder should initially sit behind a clean module/interface boundary rather than being mixed directly into the CPU datapath.

A first version can be memory-mapped:

```text
CPU
 │
 │ registers / command / data
 ▼
LDPC accelerator
 │
 └── status / result / interrupt
```

Custom instructions can be considered later only if measurements show that the memory-mapped command path is a meaningful bottleneck.

The design principle for this evolution remains: keep the RV32I core understandable and stable, and add capability around it in owned, decoupled modules.

## RV32I instruction checklist

This table intentionally contains **only real RV32I instructions**.

Excluded:
- pseudoinstructions such as `nop`, `mv`, `li`, `ret`
- M-extension multiply/divide instructions
- C compressed instructions
- CSR instructions from the separate Zicsr extension
- `FENCE.I`, which belongs to the separate Zifencei extension

Encoding notation:
- `rd`, `rs1`, `rs2` are 5-bit register fields
- `imm[...]` shows immediate-bit placement in the 32-bit instruction
- spaces separate architectural instruction fields
- fixed binary fields are written literally

Status:
- `TODO` — not yet traced
- `CHECKED` — decode through architectural effect understood
- `NOTE` — behavior understood but deserves a follow-up detail

| # | Instruction | Class | Binary encoding (31 → 0) | Architectural effect | RTL status | RTL notes |
|---:|---|---|---|---|---|---|
| 1 | `LUI rd, imm` | U | `imm[31:12] rd 0110111` | `rd = imm << 12` | TODO | |
| 2 | `AUIPC rd, imm` | U | `imm[31:12] rd 0010111` | `rd = pc + (imm << 12)` | TODO | |
| 3 | `JAL rd, off` | J | `imm[20] imm[10:1] imm[11] imm[19:12] rd 1101111` | `rd = pc+4; pc += off` | TODO | |
| 4 | `JALR rd, rs1, imm` | I | `imm[11:0] rs1 000 rd 1100111` | `rd = pc+4; pc = (rs1+imm) & ~1` | TODO | |
| 5 | `BEQ rs1, rs2, off` | B | `imm[12] imm[10:5] rs2 rs1 000 imm[4:1] imm[11] 1100011` | branch if `rs1 == rs2` | TODO | |
| 6 | `BNE rs1, rs2, off` | B | `imm[12] imm[10:5] rs2 rs1 001 imm[4:1] imm[11] 1100011` | branch if `rs1 != rs2` | TODO | |
| 7 | `BLT rs1, rs2, off` | B | `imm[12] imm[10:5] rs2 rs1 100 imm[4:1] imm[11] 1100011` | signed `rs1 < rs2` | TODO | |
| 8 | `BGE rs1, rs2, off` | B | `imm[12] imm[10:5] rs2 rs1 101 imm[4:1] imm[11] 1100011` | signed `rs1 >= rs2` | TODO | |
| 9 | `BLTU rs1, rs2, off` | B | `imm[12] imm[10:5] rs2 rs1 110 imm[4:1] imm[11] 1100011` | unsigned `rs1 < rs2` | TODO | |
| 10 | `BGEU rs1, rs2, off` | B | `imm[12] imm[10:5] rs2 rs1 111 imm[4:1] imm[11] 1100011` | unsigned `rs1 >= rs2` | TODO | |
| 11 | `LB rd, imm(rs1)` | I/load | `imm[11:0] rs1 000 rd 0000011` | load byte, sign-extend | TODO | |
| 12 | `LH rd, imm(rs1)` | I/load | `imm[11:0] rs1 001 rd 0000011` | load halfword, sign-extend | TODO | |
| 13 | `LW rd, imm(rs1)` | I/load | `imm[11:0] rs1 010 rd 0000011` | load word | TODO | |
| 14 | `LBU rd, imm(rs1)` | I/load | `imm[11:0] rs1 100 rd 0000011` | load byte, zero-extend | TODO | |
| 15 | `LHU rd, imm(rs1)` | I/load | `imm[11:0] rs1 101 rd 0000011` | load halfword, zero-extend | TODO | |
| 16 | `SB rs2, imm(rs1)` | S/store | `imm[11:5] rs2 rs1 000 imm[4:0] 0100011` | store low byte | TODO | |
| 17 | `SH rs2, imm(rs1)` | S/store | `imm[11:5] rs2 rs1 001 imm[4:0] 0100011` | store low halfword | TODO | |
| 18 | `SW rs2, imm(rs1)` | S/store | `imm[11:5] rs2 rs1 010 imm[4:0] 0100011` | store word | TODO | |
| 19 | `ADDI rd, rs1, imm` | I/ALU | `imm[11:0] rs1 000 rd 0010011` | `rd = rs1 + imm` | TODO | |
| 20 | `SLTI rd, rs1, imm` | I/ALU | `imm[11:0] rs1 010 rd 0010011` | signed less-than immediate | TODO | |
| 21 | `SLTIU rd, rs1, imm` | I/ALU | `imm[11:0] rs1 011 rd 0010011` | unsigned less-than immediate | TODO | |
| 22 | `XORI rd, rs1, imm` | I/ALU | `imm[11:0] rs1 100 rd 0010011` | bitwise XOR immediate | TODO | |
| 23 | `ORI rd, rs1, imm` | I/ALU | `imm[11:0] rs1 110 rd 0010011` | bitwise OR immediate | TODO | |
| 24 | `ANDI rd, rs1, imm` | I/ALU | `imm[11:0] rs1 111 rd 0010011` | bitwise AND immediate | TODO | |
| 25 | `SLLI rd, rs1, shamt` | I/shift | `0000000 shamt rs1 001 rd 0010011` | logical left shift | TODO | |
| 26 | `SRLI rd, rs1, shamt` | I/shift | `0000000 shamt rs1 101 rd 0010011` | logical right shift | TODO | |
| 27 | `SRAI rd, rs1, shamt` | I/shift | `0100000 shamt rs1 101 rd 0010011` | arithmetic right shift | TODO | |
| 28 | `ADD rd, rs1, rs2` | R | `0000000 rs2 rs1 000 rd 0110011` | `rd = rs1 + rs2` | TODO | |
| 29 | `SUB rd, rs1, rs2` | R | `0100000 rs2 rs1 000 rd 0110011` | `rd = rs1 - rs2` | TODO | |
| 30 | `SLL rd, rs1, rs2` | R | `0000000 rs2 rs1 001 rd 0110011` | logical left shift | TODO | |
| 31 | `SLT rd, rs1, rs2` | R | `0000000 rs2 rs1 010 rd 0110011` | signed less-than | TODO | |
| 32 | `SLTU rd, rs1, rs2` | R | `0000000 rs2 rs1 011 rd 0110011` | unsigned less-than | TODO | |
| 33 | `XOR rd, rs1, rs2` | R | `0000000 rs2 rs1 100 rd 0110011` | bitwise XOR | TODO | |
| 34 | `SRL rd, rs1, rs2` | R | `0000000 rs2 rs1 101 rd 0110011` | logical right shift | TODO | |
| 35 | `SRA rd, rs1, rs2` | R | `0100000 rs2 rs1 101 rd 0110011` | arithmetic right shift | TODO | |
| 36 | `OR rd, rs1, rs2` | R | `0000000 rs2 rs1 110 rd 0110011` | bitwise OR | TODO | |
| 37 | `AND rd, rs1, rs2` | R | `0000000 rs2 rs1 111 rd 0110011` | bitwise AND | TODO | |
| 38 | `FENCE` | memory ordering | `fm pred succ 00000 000 00000 0001111` | order memory/device accesses | TODO | |
| 39 | `ECALL` | SYSTEM | `000000000000 00000 000 00000 1110011` | environment call | TODO | |
| 40 | `EBREAK` | SYSTEM | `000000000001 00000 000 00000 1110011` | breakpoint request | TODO | |

## RTL-order walkthrough

We will grow this section as we move downward through `picorv32.v`. The order below follows the upstream source rather than grouping topics by ISA instruction.

### 0. File setup and core boundary — DONE

S01 covered the module parameters through line 88. S02 covered the module port list and local parameters through line 173.

Document:

- preprocessor/debug/formal macros relevant to understanding the source
- `picorv32` module parameters
- top-level memory interface
- look-ahead memory interface
- optional PCPI/IRQ/RVFI/trace interfaces
- which parameters are fixed for our RV32I implementation

Implementation result: define the external contract of our future core before implementing any internals.

### 1. Core state and register file — DONE

S03 covered study RTL lines 174–348. Lines 255–348 are PCPI-only and skipped.

Document:

- cycle/instruction counters
- `reg_pc`, `reg_next_pc`
- `reg_op1`, `reg_op2`, `reg_out`, `reg_sh`
- integer register file `cpuregs`
- x0 handling
- state needed only by excluded optional features

Implementation result: define the persistent datapath state.

### 2. Optional PCPI multiply/divide plumbing — SKIPPED (S03)

The upstream source encounters this before the memory interface. Record where it connects to the base core, but our RV32I implementation does not need the internal multiplier/divider/PCPI machinery.

### 3. Memory interface — IN PROGRESS

S04 began from the old line-preserving view at lines 349–643. From S04 onward, use the cleaned file instead; its memory-interface section begins at line 47. Split into sub-sessions as needed.

This is the first substantial base-RV32I subsystem in source order.

Document:

- `mem_state`
- `mem_do_prefetch`, `mem_do_rinst`, `mem_do_rdata`, `mem_do_wdata`
- `mem_valid/mem_ready` transaction lifecycle
- instruction versus data transactions
- `mem_wordsize`
- byte/halfword/word lane selection
- load-data extraction
- store-data replication and write strobes
- look-ahead interface versus committed memory request
- which compressed-instruction paths disappear when `COMPRESSED_ISA=0`

Implementation result: enough detail to build the CPU's fetch/load/store bus controller independently.

### 4. Instruction decoder — TODO

Document in the exact order the RTL introduces and computes decode state:

- individual `instr_*` flags
- grouped `is_*` flags
- `decoded_rd`, `decoded_rs1`, `decoded_rs2`
- immediate generation
- decode trigger/latching behavior
- illegal-instruction detection
- instruction families sharing datapath/control logic

Implementation result: a decoder specification that maps a 32-bit RV32I instruction to operands, immediate, destination and control class.

### 5. Debug/decode bookkeeping — TODO / mostly nonessential

Separate implementation-essential decode state from source-only debug/trace helpers. Our own core should not inherit machinery merely because it appears in the reference source.

### 6. Datapath helpers, register access and ALU — TODO

Document:

- register-file read addresses/data
- writeback enable/address/data
- x0 suppression
- ALU input selection
- ADD/SUB/logic/compare operations
- signed versus unsigned compare
- barrel versus iterative shift behavior, retaining only the configuration we choose

Implementation result: reconstruct the integer datapath independently of the main control FSM.

### 7. Main CPU control state machine — TODO

Document each state in source order, including at least:

```text
FETCH
LD_RS1
LD_RS2
EXEC
SHIFT
STMEM
LDMEM
TRAP
```

For every state record:

- entry condition
- state-owned actions
- memory request started/completed
- register values latched
- next state
- architectural effect, if any

Implementation result: this becomes the central control specification for our own multi-cycle RV32I core.

### 8. Misalignment, trap and excluded optional tail logic — TODO

Document only the parts needed for the selected RV32I behavior:

- misaligned instruction/data detection
- illegal instruction behavior
- `ECALL` / `EBREAK`
- base trap behavior

Mark IRQ, RVFI and formal-verification machinery as reference/support logic rather than required datapath/control logic.

## Source map

A useful conceptual map of `picorv32.v`:

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

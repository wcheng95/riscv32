# PicoRV32 RTL Reading Notes

This is a relaxed side track for reading the upstream PicoRV32 RTL used by this repository.

The goal is **understanding**, not finishing a syllabus and not modifying the core. The main `riscv32` labs remain the structured path; this document is a source-reading notebook we can return to whenever CPU RTL is interesting.

The repository carries PicoRV32 from upstream commit `ef203c2b0a3fb793280f5114941416c425c5b461`. Keep `picorv32/picorv32.v` unmodified and record observations here.

## How to use this track

- Read one small RTL region at a time.
- Start from a concrete question instead of trying to read the file linearly.
- Follow signals only as far as needed to answer that question.
- Prefer a tiny simulation or existing bus trace when behavior is easier to see than infer.
- Distinguish standard RISC-V behavior from PicoRV32 implementation choices.
- No schedule, no completion target, and no requirement to follow the topics below in order.

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
   - optional compressed-instruction path

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

8. **Optional machinery**
   - PCPI multiply/divide
   - PicoRV32 custom IRQ mechanism
   - counters
   - trace and formal/RVFI support

## First questions worth asking

These are prompts, not assignments:

- What exactly causes the PC to advance?
- Where does an instruction become "decoded"?
- How does the core wait when memory does not assert `mem_ready`?
- Why are `reg_pc` and `reg_next_pc` both needed?
- Where are rs1 and rs2 read, and when is rd written?
- How is x0 prevented from behaving like an ordinary register?
- How does an ADD travel through the control/state machine?
- How does a taken branch differ from an ordinary ALU instruction?
- How many cycles does a load require, and which part is core latency versus memory latency?
- Which parts disappear when optional features are disabled?

## Reading style

For each topic, keep notes short:

```text
Question
What am I trying to understand?

RTL
Which small block/signals answer it?

Mental model
Describe the behavior in plain language.

Evidence
Optional simulation/trace/measurement.

Open question
Only if something remains unclear.
```

The notebook should grow from actual questions rather than attempting to document every line of PicoRV32.

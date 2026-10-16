# PicoRV32 RV32I study RTL

There are now three deliberately different RTL views:

```text
picorv32/picorv32.v
        ↓
docs/rtl/picorv32-rv32i-study.v    line-preserving audit/reference
        ↓
docs/rtl/picorv32-rv32i-clean.v    Phase A: cleaned fixed-RV32I PicoRV32
        ↓
rtl/rv32_core.v                     Phase B: independent own core
```

## Which file to study

Use **`picorv32-rv32i-clean.v` as the primary PicoRV32 study file from S04 onward**.

The line-preserving `picorv32-rv32i-study.v` remains available only as an audit/reference snapshot. It preserves the upstream line numbering but intentionally contains dead fixed-parameter expressions.

Do **not** switch the current PicoRV32 walkthrough to `rtl/rv32_core.v`. That file is the future independent core and should stay secondary until the PicoRV32 walkthrough is complete.

## Phase A validation

`picorv32-rv32i-clean.v` keeps PicoRV32's fixed RV32I control/timing structure while removing disabled feature families and fixed configuration branches.

Validation target:

```sh
make test-clean-equiv RISCV_PREFIX=riscv64-unknown-elf-
```

The lockstep test instantiates the pinned upstream PicoRV32 and the cleaned core with identical RAMs, then compares every valid native-bus transaction cycle by cycle.

Validated in CI:

- Lab00 through Lab06
- Lab06 again with 3 inserted memory wait states

Result: **PASS**.

## Phase B validation

`../../rtl/rv32_core.v` is an independent, simpler RV32I implementation:

- one instruction in flight
- no instruction prefetch/look-ahead path
- simple fetch / execute / memory / trap FSM
- same 32-bit `mem_valid/mem_ready` native bus
- no C, M, PCPI, IRQ, counters or trace

Validation target:

```sh
make test-own-rv32i RISCV_PREFIX=riscv64-unknown-elf-
```

Validated in CI:

- Labs 00–06
- Lab06 with 3 memory wait states
- Lab08 register/ALU sequence
- Lab09 illegal-instruction trap
- Lab09 misalignment trap
- Lab13 C ABI at `-O0`
- Lab13 C ABI at `-Os`

Result: **PASS**.

The independent core is intentionally not cycle-equivalent to PicoRV32; only architectural behavior is expected to match.

## Fixed study configuration

```text
ENABLE_COUNTERS       = 0
ENABLE_COUNTERS64     = 0
ENABLE_REGS_16_31     = 1
ENABLE_REGS_DUALPORT  = 1
LATCHED_MEM_RDATA     = 0
TWO_STAGE_SHIFT       = 1
BARREL_SHIFTER        = 0
TWO_CYCLE_COMPARE     = 0
TWO_CYCLE_ALU         = 0
COMPRESSED_ISA        = 0
CATCH_MISALIGN        = 1
CATCH_ILLINSN         = 1
ENABLE_PCPI           = 0
ENABLE_MUL            = 0
ENABLE_FAST_MUL       = 0
ENABLE_DIV            = 0
ENABLE_IRQ            = 0
ENABLE_IRQ_QREGS      = 0
ENABLE_IRQ_TIMER      = 0
ENABLE_TRACE          = 0
REGS_INIT_ZERO        = 0
```

No optional debug/formal defines are enabled. `PICORV32_REGS` is not defined, so
the built-in register file path is selected.

## Projection rules

This is intentionally **not** synthesis output and **not** elaborated/optimized RTL.

- Original line count is preserved.
- Removed source lines become blank lines.
- Retained source lines remain byte-for-byte identical and at the same line number.
- The only retained-line edits are the fixed parameter defaults on source lines
  63, 64, 80 and 81, plus the study marker on line 23.
- Inactive Verilog preprocessor branches are removed.
- The two large blocks guarded only by `COMPRESSED_ISA` are removed.
- Modules following the primary `picorv32` `endmodule` are removed.
- Parameter-dead expressions inside otherwise live RTL are **not algebraically
  simplified**. For example, an expression containing `ENABLE_IRQ` may remain.
  Removing or rewriting such expressions would turn this into an elaborated or
  optimized derivative, which is explicitly not the goal.

This policy gives us a much quieter source file while preserving direct
cross-reference to the original RTL.

## Regenerate

From the repository root:

```sh
python3 tools/make_picorv32_rv32i_study.py
```

The generator refuses to proceed if the pinned upstream PicoRV32 blob no longer
matches the source it was written for.


## Licensing

PicoRV32 is licensed under the ISC License. The upstream license permits use,
copying, modification, and distribution, including for commercial purposes,
provided that the original copyright notice and permission notice are retained.

Because both `picorv32-rv32i-clean.v` and `../../rtl/rv32_core.v` were developed
from PicoRV32 source/structure, this repository conservatively treats them as
PicoRV32-derived works and carries the full ISC notice in each source file.

The pinned upstream license is also retained at `../../picorv32/COPYING`.

Future extensions to `rv32_core.v` (for example Zicsr, Machine-mode traps,
timers, and accelerators) may be original work, but keeping the ISC notice on
the evolving file preserves compliance for the PicoRV32-derived portions.

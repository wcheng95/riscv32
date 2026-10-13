# PicoRV32 RV32I study RTL

`picorv32-rv32i-study.v` is a **line-preserving source projection** of
`../../picorv32/picorv32.v`.

It is for reading and documentation only. The canonical RTL remains the unmodified
upstream copy under `picorv32/`.

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

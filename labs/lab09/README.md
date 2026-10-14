# Lab09 — Traps and Alignment

## Goal

Observe PicoRV32's terminal `trap` signal for two independent failures. **No standard privileged exception handler is installed**: PicoRV32's default behavior is to stop at a trap. Later interrupt labs study its separate custom IRQ mechanism.

## Cases

1. **Illegal instruction:** `0xffffffff` at PC 0, with `CATCH_ILLINSN=1`.
2. **Misaligned access:** `lw x2,2(x1)` where `x1=0x1000`, with `CATCH_MISALIGN=1`.

Both parameters default to 1 in upstream PicoRV32; the shared testbench now sets them explicitly.

## Run on Mac mini

```sh
git pull
make test LAB=lab09
make wave LAB=lab09 CASE=illegal
make wave LAB=lab09 CASE=misalign
```

`make test LAB=lab09` runs **both** expected-trap cases. Use `CASE=illegal` or `CASE=misalign` for an individual run. The trace and VCD stay in `build/`. Both programs are assembled with the normal RV32I toolchain; `illegal.S` inserts the invalid encoding using `.word`.

## What to inspect

- Does `trap` become asserted within the timeout?
- For the illegal case, which instruction fetch precedes the trap?
- For the misalignment case, is the offending `lw` fetched, and does a memory *data-read handshake* occur? Do not assume it will.
- Why does our expected-trap PASS condition differ from the earlier labs' store-based completion?

## Questions

1. Why isn't `trap` equivalent to an interrupt request?
2. Which architectural alignment is required for a 32-bit `lw`?
3. Why is a failed load not allowed to silently round its address down to 0x1000?
4. Does this core implement the conventional privileged `mtvec/mepc/mcause/mret` mechanism?
5. What happens if `CATCH_MISALIGN=0`? (Do not change it in this lab.)

## Completion

**PASS — both expected-trap cases validated on Mac mini.**

## Observed results (2026-10-13)

```text
illegal.S:
PASS: Lab09 expected trap cycles=7

misalign.S:
PASS: Lab09 expected trap cycles=14
```

These are elapsed testbench cycles to the expected trap assertion, not individual instruction CPI values. The illegal opcode is detected after fetch/decode; the misaligned-load program first constructs address 0x1000 and then attempts a word load at 0x1002. No normal completion or expected data-store result is required for these cases.

Both cases used the unmodified PicoRV32 RTL with `CATCH_ILLINSN=1` and `CATCH_MISALIGN=1`. The shared testbench intentionally treats the `trap` assertion as success only for Lab09. Waveform inspection remains optional.


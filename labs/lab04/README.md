# Lab04 — Loads, Stores, and Byte Enables

## Goal

Observe how RV32I moves 8-, 16-, and 32-bit values between registers and memory. Distinguish **sign extension** from **zero extension**, and inspect PicoRV32's four physical write strobes. Only aligned accesses are used here; misalignment/traps are a separate experiment.

## Program

See [lab04.S](lab04.S). The source constructs the 32-bit word `0x80ff7f01` and stores it at `0x1000`. Little-endian memory contains:

| Byte address | Data |
| --- | --- |
| `0x1000` | `01` |
| `0x1001` | `7f` |
| `0x1002` | `ff` |
| `0x1003` | `80` |

The program then performs `lb`, `lbu`, `lh`, `lhu`, `sb`, `sh` and `lw`.

## Expected verification

| Store address | Result | Explanation |
| --- | --- | --- |
| `0x1000` | `80ff7f01` | Original word |
| `0x1004` | `0000007f` | `lb` from +1, signed positive byte |
| `0x1008` | `000000ff` | `lbu` from +2, zero-extended |
| `0x100c` | `ffff80ff` | `lh` from +2, sign-extended |
| `0x1010` | `000080ff` | `lhu` from +2, zero-extended |
| `0x1014` | partial writes | `sb` lane 1, then `sh` lanes 2–3 |
| `0x1018` | `7f010113` | `lw` reads combined partial writes |

The word at `0x1014` initially contains the RAM model's default NOP `0x00000013`. The byte store changes byte lane 1 to `01`; the halfword store changes lanes 2 and 3 to `01 7f`. Byte lane 0 remains `13`. The combined result is `0x7f010113`.

The testbench verifies all eight stores, their addresses and strobes, the final RAM results and absence of unexpected traps.

## Run on Mac mini

```sh
git pull
make test LAB=lab04
make disasm LAB=lab04
cat build/bus.trace
make wave LAB=lab04
```

All traces and waveforms remain under `build/`. The one shared `riscv32_tb.v`, `ram.v`, and `bus_trace.v` continue to own the simulation machine.

## Questions

1. Why do `lb` and `lbu` produce different results for `0xff`?
2. How does a signed halfword `0x80ff` become `0xffff80ff`?
3. Which `mem_wstrb` bits are set for a byte store at byte offset 1 and a halfword store at offset 2?
4. Why does `lw` return `0x7f010113` after partial writes?
5. Why should we test misaligned loads/stores separately rather than assuming this RAM model defines their architectural behavior?

## Completion

**PASS — Mac mini functional validation complete.** Eight accepted stores; 107 testbench cycles.

## Observed Mac mini result

```text
STORE 0 addr=00001000 data=80ff7f01
STORE 1 addr=00001004 data=0000007f
STORE 2 addr=00001008 data=000000ff
STORE 3 addr=0000100c data=ffff80ff
STORE 4 addr=00001010 data=000080ff
STORE 5 addr=00001014 data=01010101
STORE 6 addr=00001014 data=7f017f01
STORE 7 addr=00001018 data=7f010113
PASS: Lab04 load/store widths and strobes cycles=107
```

### Native bus trace observations

- Byte store: cycle 85, address `0x1014`, `mem_wdata=01010101`, `mem_wstrb=0010`.
- Halfword store: cycle 92, address `0x1014`, `mem_wdata=7f017f01`, `mem_wstrb=1100`.
- Word read: cycle 99, address `0x1014`, `mem_rdata=7f010113`.
- The four earlier byte/halfword reads all returned the aligned bus word `0x80ff7f01`; PicoRV32 selects and extends individual values internally.

**Important:** `mem_wdata` on subword writes contains repeated byte/halfword patterns. Only lanes enabled by `mem_wstrb` update memory. The bus address is word-aligned for these subword transactions; byte offset is represented in the strobes.

The original low byte `0x13` at address `0x1014` remains unchanged, resulting in final word `0x7f010113`.

The supplied trace/disassembly confirms the functional tests. Misaligned access exceptions are deliberately not part of Lab04.


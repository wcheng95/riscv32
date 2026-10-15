# Lab13 — C Compiler and RV32I ABI

## Goal

Study how GCC translates a small C function call into RV32I instructions. Compare `-O0` and `-Os`, the calling convention, stack usage, return values, and memory operations, while keeping the CPU RTL unchanged.

## Program

[lab13.c](lab13.c) deliberately uses a non-inlined function:

```c
__attribute__((noinline))
int add3(int a, int b)
{
    int sum = a + b;
    sum += 3;
    return sum;
}
```

`main` passes volatile local integers 5 and 7, then writes the returned value 15 and the value 16 to `0x1000` and `0x1004`. The volatile locals prevent complete compile-time constant folding of the arguments; the volatile MMIO stores prevent removal of the observable results. Both optimization modes must produce the same results.

## Bare-metal startup

The shared `labs/common/start.S` sets `sp=0x2000`, calls `main`, then parks if `main` returns. Stack grows down from the end of our 8 KiB RAM.

`labs/common/c.ld` places code at reset PC 0 and rejects initialized global data or BSS for this intentionally minimal C experiment. We have *not* implemented general C runtime initialization (`.data` copying, `.bss` clearing or libc). There is no MMU and no OS.

The Makefile builds an ELF with `-march=rv32i -mabi=ilp32 -ffreestanding -nostdlib`, then converts the `.text` section into the RAM instruction hex image.

## Run on Mac mini

```sh
git pull
make test LAB=lab13 OPT=0
make disasm LAB=lab13 OPT=0

make test LAB=lab13 OPT=s
make disasm LAB=lab13 OPT=s
make wave LAB=lab13 OPT=s
```

Both runs should report:

```text
STORE 0 addr=00001000 data=0000000f
STORE 1 addr=00001004 data=00000010
PASS: Lab13 C ABI results=15,16 cycles=...
```

Each optimization mode has a distinct ELF, HEX and simulator binary in `build/`, so the modes cannot silently share outdated output. The passive `build/bus.trace` is overwritten each run. The VCD is `build/lab13.vcd`.

## What to observe

- **Arguments:** RV32I ILP32 convention passes the first two scalar integer arguments in `a0` and `a1`.
- **Return value:** scalar integer returned in `a0`.
- **Return address:** `ra` (`x1`) typically saves the return address. An ordinary function return uses `ret` (assembler alias for `jalr x0,0(ra)`).
- **Stack:** `sp` (`x2`) is 16-byte aligned at call boundaries; inspect the prologue/epilogue and any saved `ra`, `s0`, locals, or caller temporaries.
- **Optimization:** GCC may eliminate or shorten frame setup, register moves and local storage at `-Os`. Do not assume one exact instruction sequence; inspect your installed GCC's actual output.
- **External bus:** Observe instruction fetches, local-variable stack accesses, and MMIO writes. The bus trace shows accesses, not an instruction retirement stream.

## Questions

1. Which registers pass `a` and `b` to `add3`?
2. Where is the return value placed?
3. What changes in `add3` at `-O0` versus `-Os`?
4. Why is `sp` initialized in assembly rather than automatically by PicoRV32?
5. Which features belong to the RV32I ISA, which to the ABI, and which to GCC's optimization?

## First Mac mini build observation

Both builds compiled and disassembled successfully, but the first simulation attempt stopped before execution: the Makefile supplied an empty `+words=` value, causing `ram.v` to reject the program size. The Makefile word-count expansion was corrected; simulation still requires rerunning.

The supplied disassembly shows the substantial optimization difference:

- `-O0`: `add3` starts at `0x10`, has a 48-byte stack frame, saves `ra` and `s0`, and spills arguments and the intermediate result.
- `-Os`: `add3` starts at `0x10` and consists of just `add`, `addi` and `ret`, without a stack frame.
- `-O0`: `main` starts at `0x5c`; `-Os`: `main` starts at `0x1c`.

These are observed compiler choices, not ABI requirements. The functional results still need validation.

## Completion

Pending Mac mini functional validation, comparison of both disassemblies and waveform inspection. Record measured results here, not in the root README.

Lab12 was intentionally skipped. This concludes the planned standalone RISC-V ISA/CPU survey once Lab13 is complete.

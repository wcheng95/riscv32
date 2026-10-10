# Mac mini environment

## Tool installation (Homebrew / Apple Silicon)

```sh
brew install icarus-verilog riscv64-elf-gcc
```

This supplies `iverilog`, `vvp`, `riscv64-elf-gcc` and the RISC-V ELF binutils. The cross-compiler has a 64-bit name but can generate RV32I code using `-march=rv32i -mabi=ilp32`. The first hardcoded-instruction test does **not** need GCC, so simulation can be verified independently.

```sh
git clone https://github.com/wcheng95/riscv32.git
cd riscv32
make test
make wave
make toolchain-check
```

The `wave` target writes `build/lab00.vcd`; open it in a waveform viewer such as Surfer.

## Architecture of Lab00

- CPU: original, unchanged `picorv32/picorv32.v`.
- Machine code: six 32-bit instructions initialized directly in the testbench.
- Unified 8 KiB memory, little-endian, at `0x0000–0x1fff`.
- Code at `0x0000`, result at `0x1000`.
- Native memory bus: `mem_valid`, `mem_ready`, `mem_addr`, `mem_wdata`, `mem_wstrb`, `mem_rdata`.
- Registered memory reply and bounded CPU timeout.
- Expected full-word store of decimal `12` to address `0x1000`.

No monitor peripheral or linker script is required for this first experiment. Those will be added when software-generated output and compiled labs require them.

## Useful tools

```sh
iverilog -V | head -1
vvp -V
riscv64-elf-gcc --version | head -1
riscv64-elf-gcc -Q --help=target -march=rv32i -mabi=ilp32 2>/dev/null | head
```

The default build uses only Icarus; do not start a custom toolchain build unless the Homebrew toolchain fails to support our RV32 needs.

## Validation state

The files are provided for local macOS validation. Passing results on the Mac mini must be confirmed by running `make test` there.

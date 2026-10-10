IVERILOG ?= iverilog
VVP ?= vvp
TOP = riscv32_tb
SIM = build/lab00.vvp
SRC = tbench/riscv32_tb.v picorv32/picorv32.v

.PHONY: all test wave clean toolchain-check
all: test

build:
	mkdir -p build

$(SIM): $(SRC) | build
	$(IVERILOG) -g2012 -s $(TOP) -o $@ $(SRC)

test: $(SIM)
	$(VVP) $(SIM)

wave: $(SIM)
	$(VVP) $(SIM) +vcd
	@echo "VCD: build/lab00.vcd"

toolchain-check:
	@command -v iverilog
	@command -v vvp
	@command -v riscv64-elf-gcc
	@command -v riscv64-elf-objdump
	@riscv64-elf-gcc --version | head -1

clean:
	rm -rf build

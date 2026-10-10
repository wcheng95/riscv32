IVERILOG ?= iverilog
VVP ?= vvp
PYTHON ?= python3
RISCV_PREFIX ?= riscv64-elf-
CC = $(RISCV_PREFIX)gcc
OBJCOPY = $(RISCV_PREFIX)objcopy
OBJDUMP = $(RISCV_PREFIX)objdump

LAB ?= lab00
ifeq ($(filter $(LAB),lab00 lab01),)
$(error Unsupported LAB=$(LAB); choose lab00 or lab01)
endif

ifeq ($(LAB),lab00)
TOP = riscv32_tb
TB = tbench/riscv32_tb.v
else
TOP = lab01_tb
TB = tbench/lab01_tb.v
endif

SIM = build/$(LAB).vvp
SRC = $(TB) picorv32/picorv32.v
ASFLAGS = -march=rv32i -mabi=ilp32 -mno-relax -nostdlib -nostartfiles -Wl,-T,labs/common/link.ld -Wl,--build-id=none

.PHONY: all test wave disasm clean toolchain-check test-all
all: test

build:
	mkdir -p build

build/lab00.elf: labs/lab00/lab00.S labs/common/link.ld | build
	$(CC) $(ASFLAGS) -o $@ $<

build/lab01.elf: labs/lab01/lab01.S labs/common/link.ld | build
	$(CC) $(ASFLAGS) -o $@ $<

build/%.bin: build/%.elf
	$(OBJCOPY) -O binary -j .text $< $@

build/%.hex: build/%.bin tools/bin2hex.py
	$(PYTHON) tools/bin2hex.py $< $@

$(SIM): build/$(LAB).hex $(SRC) | build
	$(IVERILOG) -g2012 -s $(TOP) -o $@ $(SRC)

test: $(SIM)
	$(VVP) $(SIM)

test-all:
	$(MAKE) test LAB=lab00
	$(MAKE) test LAB=lab01

wave: $(SIM)
	$(VVP) $(SIM) +vcd
	@echo "VCD: build/$(LAB).vcd"

disasm: build/$(LAB).elf
	$(OBJDUMP) -d $<

toolchain-check:
	@command -v iverilog
	@command -v vvp
	@command -v $(CC)
	@command -v $(OBJDUMP)
	@$(CC) --version | head -1

clean:
	rm -rf build

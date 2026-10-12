IVERILOG ?= iverilog
VVP ?= vvp
PYTHON ?= python3
RISCV_PREFIX ?= riscv64-elf-
CC = $(RISCV_PREFIX)gcc
OBJCOPY = $(RISCV_PREFIX)objcopy
OBJDUMP = $(RISCV_PREFIX)objdump

LAB ?= lab00
ifeq ($(filter $(LAB),lab00 lab01 lab02 lab03 lab04),)
$(error Unsupported LAB=$(LAB); choose lab00 through lab04)
endif

TOP = riscv32_tb
SIM = build/$(LAB).vvp
SRC = tbench/riscv32_tb.v tbench/ram.v tbench/bus_trace.v picorv32/picorv32.v
LAB_ID = $(patsubst lab%,%,$(LAB))
WORDS_lab00 = 6
WORDS_lab01 = 10
WORDS_lab02 = 14
WORDS_lab03 = 12
WORDS_lab04 = 17
WORDS = $(WORDS_$(LAB))
RUN_ARGS = +lab=$(LAB_ID) +hex=build/$(LAB).hex +words=$(WORDS)

ASFLAGS = -march=rv32i -mabi=ilp32 -mno-relax -nostdlib -nostartfiles -Wl,-T,labs/common/link.ld -Wl,--build-id=none

.PHONY: all test trace wave disasm clean toolchain-check test-all
all: test

build:
	mkdir -p build

build/lab00.elf: labs/lab00/lab00.S labs/common/link.ld | build
	$(CC) $(ASFLAGS) -o $@ $<

build/lab01.elf: labs/lab01/lab01.S labs/common/link.ld | build
	$(CC) $(ASFLAGS) -o $@ $<

build/lab02.elf: labs/lab02/lab02.S labs/common/link.ld | build
	$(CC) $(ASFLAGS) -o $@ $<

build/lab03.elf: labs/lab03/lab03.S labs/common/link.ld | build
	$(CC) $(ASFLAGS) -o $@ $<

build/lab04.elf: labs/lab04/lab04.S labs/common/link.ld | build
	$(CC) $(ASFLAGS) -o $@ $<

build/%.bin: build/%.elf
	$(OBJCOPY) -O binary -j .text $< $@

build/%.hex: build/%.bin tools/bin2hex.py
	$(PYTHON) tools/bin2hex.py $< $@

$(SIM): build/$(LAB).hex $(SRC) | build
	$(IVERILOG) -g2012 -s $(TOP) -o $@ $(SRC)

test: $(SIM)
	$(VVP) $(SIM) $(RUN_ARGS) +trace
	@echo "Trace: build/bus.trace"

trace: $(SIM)
	$(VVP) $(SIM) $(RUN_ARGS) +trace
	@echo "Trace: build/bus.trace"

test-all:
	$(MAKE) test LAB=lab00
	$(MAKE) test LAB=lab01
	$(MAKE) test LAB=lab02
	$(MAKE) test LAB=lab03
	$(MAKE) test LAB=lab04

wave: $(SIM)
	$(VVP) $(SIM) $(RUN_ARGS) +trace +vcd
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

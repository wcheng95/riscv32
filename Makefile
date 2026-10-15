IVERILOG ?= iverilog
VVP ?= vvp
PYTHON ?= python3
RISCV_PREFIX ?= riscv64-elf-
CC = $(RISCV_PREFIX)gcc
OBJCOPY = $(RISCV_PREFIX)objcopy
OBJDUMP = $(RISCV_PREFIX)objdump

LAB ?= lab00
ifeq ($(filter $(LAB),lab00 lab01 lab02 lab03 lab04 lab05 lab06 lab07 lab08 lab09 lab10 lab11 lab13),)
$(error Unsupported LAB=$(LAB); choose lab00 through lab11, or lab13)
endif

TOP = riscv32_tb
REGS ?= 1
ifneq ($(filter $(REGS),0 1),$(REGS))
$(error REGS must be 0 or 1)
endif
IRQ_ENABLE = $(if $(filter lab10,$(LAB)),1,0)
PCPI_ENABLE = $(if $(filter lab11,$(LAB)),1,0)
OPT ?= s
ifneq ($(filter $(OPT),0 s),$(OPT))
$(error OPT must be 0 or s)
endif
SIM = build/$(LAB)$(if $(filter lab13,$(LAB)),_$(OPT),)_regs$(REGS).vvp
SRC = tbench/riscv32_tb.v tbench/ram.v tbench/bus_trace.v tbench/irq_source.v tbench/pcpi_demo.v picorv32/picorv32.v
LAB_ID = $(patsubst lab%,%,$(LAB))
WORDS_lab00 = 6
WORDS_lab01 = 10
WORDS_lab02 = 14
WORDS_lab03 = 12
WORDS_lab04 = 17
WORDS_lab05 = 19
WORDS_lab06 = 7
WORDS_lab07 = 16
WORDS_lab08 = 10
WORDS_lab09 = 2
WORDS_lab10 = 36
WORDS_lab11 = 8
CASE ?= illegal
ifeq ($(LAB),lab09)
ifneq ($(filter $(CASE),illegal misalign),$(CASE))
$(error CASE must be illegal or misalign)
endif
RUN_ARGS = +lab=$(LAB_ID) +hex=build/lab09_$(CASE).hex +words=$(if $(filter misalign,$(CASE)),3,2) +wait=$(WAIT)
else ifeq ($(LAB),lab13)
RUN_ARGS = +lab=13 +hex=build/lab13_$(OPT).hex +words=$(wc -l < build/lab13_$(OPT).hex) +wait=$(WAIT)
else
RUN_ARGS = +lab=$(LAB_ID) +hex=build/$(LAB).hex +words=$(WORDS) +wait=$(WAIT)
endif
WORDS = $(WORDS_$(LAB))
WAIT ?= 0
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

build/lab05.elf: labs/lab05/lab05.S labs/common/link.ld | build
	$(CC) $(ASFLAGS) -o $@ $<

build/lab06.elf: labs/lab06/lab06.S labs/common/link.ld | build
	$(CC) $(ASFLAGS) -o $@ $<

build/lab07.elf: labs/lab07/lab07.S labs/common/link.ld | build
	$(CC) $(ASFLAGS) -o $@ $<

build/lab08.elf: labs/lab08/lab08.S labs/common/link.ld | build
	$(CC) $(ASFLAGS) -o $@ $<

build/lab10.elf: labs/lab10/lab10.S labs/common/link.ld | build
	$(CC) $(ASFLAGS) -o $@ $<

build/lab11.elf: labs/lab11/lab11.S labs/common/link.ld | build
	$(CC) $(ASFLAGS) -o $@ $<

build/lab13_%.elf: labs/common/start.S labs/lab13/lab13.c labs/common/c.ld | build
	$(CC) -march=rv32i -mabi=ilp32 -mno-relax -O$* -ffreestanding -fno-builtin -fno-stack-protector -msmall-data-limit=0 -nostdlib -nostartfiles -Wl,-T,labs/common/c.ld -Wl,--build-id=none -o $@ labs/common/start.S labs/lab13/lab13.c

build/lab09_illegal.elf: labs/lab09/illegal.S labs/common/link.ld | build
	$(CC) $(ASFLAGS) -o $@ $<

build/lab09_misalign.elf: labs/lab09/misalign.S labs/common/link.ld | build
	$(CC) $(ASFLAGS) -o $@ $<

build/%.bin: build/%.elf
	$(OBJCOPY) -O binary -j .text $< $@

build/%.hex: build/%.bin tools/bin2hex.py
	$(PYTHON) tools/bin2hex.py $< $@

ifeq ($(LAB),lab09)
FIRMWARE = build/lab09_illegal.hex build/lab09_misalign.hex
else ifeq ($(LAB),lab13)
FIRMWARE = build/lab13_$(OPT).hex
else
FIRMWARE = build/$(LAB).hex
endif
$(SIM): $(FIRMWARE) $(SRC) | build
	$(IVERILOG) -g2012 -s $(TOP) -P$(TOP).REG_DUALPORT=$(REGS) -P$(TOP).IRQ_ENABLED=$(IRQ_ENABLE) -P$(TOP).PCPI_ENABLED=$(PCPI_ENABLE) -o $@ $(SRC)

test: $(SIM)
ifeq ($(LAB),lab09)
	$(VVP) $(SIM) +lab=09 +hex=build/lab09_illegal.hex +words=2 +wait=$(WAIT) +trace
	$(VVP) $(SIM) +lab=09 +hex=build/lab09_misalign.hex +words=3 +wait=$(WAIT) +trace
else
	$(VVP) $(SIM) $(RUN_ARGS) +trace
endif
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
	$(MAKE) test LAB=lab05
	$(MAKE) test LAB=lab06
	$(MAKE) test LAB=lab07
	$(MAKE) test LAB=lab08 REGS=1
	$(MAKE) test LAB=lab08 REGS=0
	$(MAKE) test LAB=lab09
	$(MAKE) test LAB=lab10
	$(MAKE) test LAB=lab11
	$(MAKE) test LAB=lab13 OPT=0
	$(MAKE) test LAB=lab13 OPT=s

wave: $(SIM)
	$(VVP) $(SIM) $(RUN_ARGS) +trace +vcd
	@echo "VCD: build/$(LAB).vcd"

disasm: $(if $(filter lab13,$(LAB)),build/lab13_$(OPT).elf,build/$(LAB).elf)
	$(OBJDUMP) -d $<

toolchain-check:
	@command -v iverilog
	@command -v vvp
	@command -v $(CC)
	@command -v $(OBJDUMP)
	@$(CC) --version | head -1

clean:
	rm -rf build

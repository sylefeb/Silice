ARCH = $(shell ../../../../tools/bash/riscv_arch.sh)
CC   = $(ARCH)-gcc
AS   = $(ARCH)-as
LD   = $(ARCH)-ld

all : code.hex

code.elf : main.o div.o crt0.o
		$(LD) -m elf32lriscv -b elf32-littleriscv -Tconfig_c.ld --no-relax -o code.elf $^

code.hex : code.elf
		$(ARCH)-objcopy -O verilog code.elf code.hex

%.o : %.c
		$(CC) -fno-builtin -fno-unroll-loops -O1 -fno-stack-protector -fno-pic -march=rv32i -mabi=ilp32 -c $< -o $@

%.o : %.s
		$(AS) -march=rv32i -mabi=ilp32 $< -o $@

clean:
	rm *.o *.hex *.elf
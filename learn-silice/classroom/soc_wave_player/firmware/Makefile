TSTS = $(wildcard step*.c test*.c)
PRGS = $(basename $(TSTS))
ARCH = $(shell bash ../../../../tools/bash/riscv_arch.sh)
CC   = $(ARCH)-gcc
AS   = $(ARCH)-as
LD   = $(ARCH)-ld
OBJS = sdcard.o div.o std.o config.o oled.o display.o printf.o mul.o crt0.o fat_io_lib.o

$(PRGS): %: %.o $(OBJS)
		$(LD) -m elf32lriscv -b elf32-littleriscv -Tconfig_c.ld --no-relax -o code.elf $^
		$(ARCH)-objcopy -O verilog code.elf code.hex
		$(ARCH)-objdump --disassemble code.elf > code.s

%.o : %.c
		$(CC) -U_FORTIFY_SOURCE -fno-builtin -fno-unroll-loops $(DEFINES) -Os -fno-stack-protector -fno-pic -march=rv32i -mabi=ilp32 -c $< -o $@

%.o : %.s
		$(AS) -march=rv32i -mabi=ilp32 $< -o $@

clean:
	rm -f *.o *.hex *.elf

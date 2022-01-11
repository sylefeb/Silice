ARCH = $(shell ../../../../tools/bash/riscv_arch.sh)
CC   = $(ARCH)-gcc
AS   = $(ARCH)-as
LD   = $(ARCH)-ld

test_fat32 : test_fat32.o div.o crt0.o fat_io_lib.o
		$(LD) -m elf32lriscv -b elf32-littleriscv -Tconfig_c.ld --no-relax -o code.elf $^
		$(ARCH)-objcopy -O verilog code.elf code.hex

test_sdcard : test_sdcard.o div.o crt0.o
		$(LD) -m elf32lriscv -b elf32-littleriscv -Tconfig_c.ld --no-relax -o code.elf $^
		$(ARCH)-objcopy -O verilog code.elf code.hex

test_hello_world: test_hello_world.o div.o crt0.o
		$(LD) -m elf32lriscv -b elf32-littleriscv -Tconfig_c.ld --no-relax -o code.elf $^
		$(ARCH)-objcopy -O verilog code.elf code.hex

test_menu: test_menu.o div.o crt0.o
		$(LD) -m elf32lriscv -b elf32-littleriscv -Tconfig_c.ld --no-relax -o code.elf $^
		$(ARCH)-objcopy -O verilog code.elf code.hex

%.o : %.c
		$(CC) -fno-builtin -fno-unroll-loops -O1 -fno-stack-protector -fno-pic -march=rv32i -mabi=ilp32 -c $< -o $@

%.o : %.s
		$(AS) -march=rv32i -mabi=ilp32 $< -o $@

clean:
	rm -f *.o *.hex *.elf

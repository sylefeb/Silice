ARCH = $(shell bash ../../../../tools/bash/riscv_arch.sh)
CC   = $(ARCH)-gcc
AS   = $(ARCH)-as
LD   = $(ARCH)-ld
OBJS = sdcard.o div.o std.o config.o oled.o display.o printf.o mul.o crt0.o

test_img : test_img.o $(OBJS) fat_io_lib.o
		$(LD) -m elf32lriscv -b elf32-littleriscv -Tconfig_c.ld --no-relax -o code.elf $^
		$(ARCH)-objcopy -O verilog code.elf code.hex

test_fat32 : test_fat32.o $(OBJS) fat_io_lib.o
		$(LD) -m elf32lriscv -b elf32-littleriscv -Tconfig_c.ld --no-relax -o code.elf $^
		$(ARCH)-objcopy -O verilog code.elf code.hex

test_sdcard : test_sdcard.o $(OBJS)
		$(LD) -m elf32lriscv -b elf32-littleriscv -Tconfig_c.ld --no-relax -o code.elf $^
		$(ARCH)-objcopy -O verilog code.elf code.hex

test_hello_world: test_hello_world.o $(OBJS)
		$(LD) -m elf32lriscv -b elf32-littleriscv -Tconfig_c.ld --no-relax -o code.elf $^
		$(ARCH)-objcopy -O verilog code.elf code.hex

test_menu: test_menu.o $(OBJS)
		$(LD) -m elf32lriscv -b elf32-littleriscv -Tconfig_c.ld --no-relax -o code.elf $^
		$(ARCH)-objcopy -O verilog code.elf code.hex

%.o : %.c
		$(CC) -fno-builtin -fno-unroll-loops -O1 -fno-stack-protector -fno-pic -march=rv32i -mabi=ilp32 -c $< -o $@

%.o : %.s
		$(AS) -march=rv32i -mabi=ilp32 $< -o $@

clean:
	rm -f *.o *.hex *.elf

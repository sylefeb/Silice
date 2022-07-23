icebreaker: main.si
	silice-make.py -s main.si -b $@ -p basic,vga,spiflash,buttons -o BUILD_$(subst :,_,$@) -t shell $(ARGS)

verilator: main.si
		silice-make.py -s main.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) -t shell

clean:
	rm -rf BUILD_*

spiflash: make_spiflash.si
		silice-make.py -s make_spiflash.si -b verilator -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

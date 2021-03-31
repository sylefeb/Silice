icebreaker: main.ice
	silice-make.py -s main.ice -b $@ -p basic,vga,spiflash,buttons -o BUILD_$(subst :,_,$@) -t shell

verilator: main.ice
		silice-make.py -s main.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) -t shell

clean:
	rm -rf BUILD_*

spiflash: make_spiflash.ice
		silice-make.py -s make_spiflash.ice -b verilator -p basic,vga,sdram -o BUILD_$(subst :,_,$@)

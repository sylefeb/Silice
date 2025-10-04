icebreaker: main.si
	silice-make.sh -s main.si -b $@ -p basic,vga,spiflash,buttons -o BUILD_$(subst :,_,$@) -t shell $(ARGS)

verilator: main.si
		silice-make.sh -s main.si -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) -t shell $(ARGS)

clean:
	rm -rf BUILD_*

spiflash: make_spiflash.si
		silice-make.sh -s make_spiflash.si -b verilator -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)

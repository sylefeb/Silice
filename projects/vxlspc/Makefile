icebreaker: main.ice
	silice-make.py -s main.ice -b $@ -p basic,vga,spiflash -o BUILD_$(subst :,_,$@) -t shell

verilator: main.ice
		silice-make.py -s main.ice -b $@ -p basic,vga -o BUILD_$(subst :,_,$@) -t shell

clean:
	rm -rf BUILD_*

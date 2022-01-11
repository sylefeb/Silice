
.DEFAULT: main.ice
	make -C firmware -f Makefile.fat_io_lib
	silice-make.py -s main.ice -b $@ -p basic,oled,spiflash,uart,sdcard,buttons -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: main.ice
	make -C firmware
	rm -rf BUILD_*
	silice-make.py -s main.ice -b $@ -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	make -C firmware clean
	rm -rf BUILD_*
	rm -f *.lpp

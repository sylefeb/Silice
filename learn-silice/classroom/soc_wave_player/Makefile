
.DEFAULT: main.ice
	silice-make.py -s main.ice -b $@ -p basic,oled,spiflash,uart,sdcard -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: main.ice
	rm -rf BUILD_*
	silice-make.py -s main.ice -b $@ -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
	rm -f *.lpp
	rm -f ./compile/build/*.o
	rm -f ./compile/build/*.hex
	rm crt0.o

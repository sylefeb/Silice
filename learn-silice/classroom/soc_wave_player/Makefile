FIRMWARE ?= test_hello_world

.DEFAULT: main.si
	make -C firmware $(FIRMWARE)
	silice-make.py -s main.si -b $@ -p basic,oled,spiflash,uart,sdcard,buttons,audio -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: main.si
	make -C firmware $(FIRMWARE)
	rm -rf BUILD_*
	silice-make.py -s main.si -b $@ -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	make -C firmware clean
	rm -rf BUILD_*
	rm -f *.lpp

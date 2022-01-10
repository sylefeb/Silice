
.DEFAULT: main.ice
	./compile/compile_c.sh firmware/main.c
	silice-make.py -s main.ice -b $@ -p basic,oled,spiflash -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: main.ice
	rm -rf BUILD_*
	rm -f ./compile/build/*.o
	rm -f ./compile/build/*.hex
	rm -f *.lpp
	./compile/compile_c.sh firmware/main.c
	silice-make.py -s main.ice -b $@ -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*
	rm -f *.lpp
	rm crt0.o

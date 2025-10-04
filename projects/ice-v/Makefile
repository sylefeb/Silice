
.DEFAULT: SOCs/ice-v-soc.si
		silice-make.sh -s SOCs/ice-v-soc.si -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

spiflash: make_spiflash.si
		silice-make.sh -s make_spiflash.si -b verilator -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)
		iceprog -o 256000 data.img

clean:
	rm -rf BUILD_*
	rm -f crt0.o
	rm -f SOCs/*.lpp
#	rm -f data.img spram_l.img spram_h.img

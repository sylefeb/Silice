
.DEFAULT: SOCs/ice-v-soc.ice
		silice-make.py -s SOCs/ice-v-soc.ice -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

spiflash: make_spiflash.ice
		silice-make.py -s make_spiflash.ice -b verilator -p basic,vga,sdram -o BUILD_$(subst :,_,$@) $(ARGS)
		iceprog -o 256000 data.img

clean:
	rm -rf BUILD_*
	rm -f crt0.o
	rm -f SOCs/*.lpp
#	rm -f data.img spram_l.img spram_h.img

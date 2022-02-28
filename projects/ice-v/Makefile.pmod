
.DEFAULT: SOCs/ice-v-soc.si
		silice-make.py -s SOCs/ice-v-soc.si -b $@ -p basic,pmod,spiflash -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*

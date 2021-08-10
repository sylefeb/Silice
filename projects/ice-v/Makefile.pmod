
.DEFAULT: ice-v-soc.ice
		silice-make.py -s ice-v-soc.ice -b $@ -p basic,pmod,spiflash -o BUILD_$(subst :,_,$@) -t shell $(ARGS)

clean:
	rm -rf BUILD_*

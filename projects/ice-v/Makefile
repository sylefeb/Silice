
.DEFAULT: ice-v-soc.ice
		silice-make.py -s ice-v-soc.ice -b $@ -p basic -o BUILD_$(subst :,_,$@) -t shell

clean:
	rm -rf BUILD_*

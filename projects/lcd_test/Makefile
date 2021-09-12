.DEFAULT: main.ice
		silice-make.py -s main.ice -b $@ -p basic,pmod_out -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*

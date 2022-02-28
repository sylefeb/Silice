.DEFAULT: main.si
		silice-make.py -s main.si -b $@ -p basic,pmod_out -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*

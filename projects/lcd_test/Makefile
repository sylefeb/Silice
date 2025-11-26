.DEFAULT: main.si
		silice-make.sh -s main.si -b $@ -p basic,pmod_out -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*

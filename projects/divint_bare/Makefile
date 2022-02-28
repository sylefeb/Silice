
.DEFAULT: main.si
		silice-make.py -s main.si -b $@ -p basic -o BUILD_$(subst :,_,$@)  $(ARGS)

clean:
	rm -rf BUILD_*

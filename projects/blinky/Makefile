
.DEFAULT: blinky.si
		silice-make.sh -s blinky.si -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*

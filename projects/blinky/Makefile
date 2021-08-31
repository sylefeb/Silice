
.DEFAULT: blinky.ice
		silice-make.py -s blinky.ice -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*

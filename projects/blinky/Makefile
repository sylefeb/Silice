
.DEFAULT: blinky.si
		silice-make.py -s blinky.si -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

yowasp-icestick:
		silice-make.py -s blinky.si -b $(subst yowasp-,,$@) -p basic -t yowasp -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*

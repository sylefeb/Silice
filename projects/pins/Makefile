
.DEFAULT: pins_blinky.si
		silice-make.py -s pins_blinky.si -b $@ -o BUILD_$(subst :,_,$@) $(ARGS)
#   Note how this call to silice does not specify any 'pin set' (no -p parameter).
#   That is because the design directly refers to the FPGA pins by name.

clean:
	rm -rf BUILD_*

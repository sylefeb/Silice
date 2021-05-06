
icebreaker: spram_fill.ice
	silice-make.py --no_program -s spram_fill.ice -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@)
	cp BUILD_icebreaker/build.bin ../bin/spram_fill.bin

clean:
	rm -rf BUILD_*

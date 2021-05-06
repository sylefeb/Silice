
icebreaker: bram_fill.ice
	silice-make.py --no_program -s bram_fill.ice -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@)
	cp BUILD_icebreaker/build.bin ../bin/bram_fill.bin

clean:
	rm -rf BUILD_*

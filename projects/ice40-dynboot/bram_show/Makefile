
icebreaker: bram_show.ice
	silice-make.py --no_program -s bram_show.ice -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@)
	cp BUILD_icebreaker/build.bin ../bin/bram_show.bin

clean:
	rm -rf BUILD_*

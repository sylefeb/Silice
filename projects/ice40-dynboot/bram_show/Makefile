
icebreaker: bram_show.si
	silice-make.py --no_program -s bram_show.si -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@)
	cp BUILD_icebreaker/build.bin ../bin/bram_show.bin

clean:
	rm -rf BUILD_*

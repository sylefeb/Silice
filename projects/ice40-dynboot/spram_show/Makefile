
icebreaker: spram_show.si
	silice-make.py --no_program -s spram_show.si -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@)
	cp BUILD_icebreaker/build.bin ../bin/spram_show.bin

clean:
	rm -rf BUILD_*

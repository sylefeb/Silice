
icebreaker: bram_fill.si
	silice-make.sh --no_program -s bram_fill.si -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@)
	cp BUILD_icebreaker/build.bin ../bin/bram_fill.bin

clean:
	rm -rf BUILD_*

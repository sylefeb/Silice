
icebreaker: spram_fill.si
	silice-make.sh --no_program -s spram_fill.si -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@)
	cp BUILD_icebreaker/build.bin ../bin/spram_fill.bin

clean:
	rm -rf BUILD_*

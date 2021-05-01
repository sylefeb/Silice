
blinky1: blinky1.ice
	silice-make.py --no_program -s blinky1.ice -b icebreaker -p basic,buttons -o BUILD_$(subst :,_,$@)
	cp BUILD_blinky1/build.bin blinky1.bin

blinky2: blinky2.ice
	silice-make.py --no_program -s blinky2.ice -b icebreaker -p basic,buttons -o BUILD_$(subst :,_,$@)
	cp BUILD_blinky2/build.bin blinky2.bin

program: blinky1 blinky2
	icemulti blinky1.bin blinky2.bin -o multi.bin
	iceprog multi.bin

clean:
	rm -rf BUILD_*

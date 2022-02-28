
icebreaker: blinky_reboot.si
	silice-make.py --no_program -s blinky_reboot.si -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b00001\'
	cp BUILD_icebreaker/build.bin ../bin/blinky0.bin
	silice-make.py --no_program -s blinky_reboot.si -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b00010\'
	cp BUILD_icebreaker/build.bin ../bin/blinky1.bin
	silice-make.py --no_program -s blinky_reboot.si -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b10000\'
	cp BUILD_icebreaker/build.bin ../bin/blinky2.bin
	silice-make.py --no_program -s blinky_reboot.si -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b00100\'
	cp BUILD_icebreaker/build.bin ../bin/blinky3.bin
	silice-make.py --no_program -s blinky_reboot.si -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b01000\'
	cp BUILD_icebreaker/build.bin ../bin/blinky4.bin
	silice-make.py --no_program -s blinky_reboot.si -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b11000\'
	cp BUILD_icebreaker/build.bin ../bin/blinky5.bin
	silice-make.py --no_program -s blinky_reboot.si -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b00110\'
	cp BUILD_icebreaker/build.bin ../bin/blinky6.bin
	silice-make.py --no_program -s blinky_reboot.si -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b11110\'
	cp BUILD_icebreaker/build.bin ../bin/blinky7.bin

clean:
	rm -rf BUILD_*

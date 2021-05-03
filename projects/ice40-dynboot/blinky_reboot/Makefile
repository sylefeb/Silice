
icebreaker: blinky_reboot.ice
	silice-make.py --no_program -s blinky_reboot.ice -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b00001\'
	cp BUILD_icebreaker/build.bin ../bin/blinky0.bin
	silice-make.py --no_program -s blinky_reboot.ice -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b00010\'
	cp BUILD_icebreaker/build.bin ../bin/blinky1.bin
	silice-make.py --no_program -s blinky_reboot.ice -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b00011\'
	cp BUILD_icebreaker/build.bin ../bin/blinky2.bin
	silice-make.py --no_program -s blinky_reboot.ice -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b00100\'
	cp BUILD_icebreaker/build.bin ../bin/blinky3.bin
	silice-make.py --no_program -s blinky_reboot.ice -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b00101\'
	cp BUILD_icebreaker/build.bin ../bin/blinky4.bin
	silice-make.py --no_program -s blinky_reboot.ice -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b00110\'
	cp BUILD_icebreaker/build.bin ../bin/blinky5.bin
	silice-make.py --no_program -s blinky_reboot.ice -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b00111\'
	cp BUILD_icebreaker/build.bin ../bin/blinky6.bin
	silice-make.py --no_program -s blinky_reboot.ice -b $@ -p basic,buttons -o BUILD_$(subst :,_,$@) -D LEDs=\'5b01000\'
	cp BUILD_icebreaker/build.bin ../bin/blinky7.bin

clean:
	rm -rf BUILD_*

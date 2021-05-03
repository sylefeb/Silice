
icebreaker: ../fire-v/spark.ice
		make -C blinky_reboot
		./compile.sh
		silice-make.py --no_program -s ../fire-v/spark.ice -b $@ -p basic,spiflash -o BUILD_$(subst :,_,$@) -D WARMBOOT=1
		cp BUILD_icebreaker/build.bin bin/bootloader.bin
		icemulti bin/bootloader.bin -o bin/multi.bin
		cp bin/multi.bin bin/header.bin
		truncate -s 4096 bin/header.bin
		iceprog bin/header.bin -o 1M
		cat bin/multi.bin bin/blinky* > bin/package.bin
		iceprog bin/package.bin

clean:
	rm -rf BUILD_*

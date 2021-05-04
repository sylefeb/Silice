
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

spram_test: ../fire-v/spark.ice
		make -C spram_fill
		make -C spram_show
		./compile.sh
		silice-make.py --no_program -s ../fire-v/spark.ice -b icebreaker -p basic,spiflash -o BUILD_$(subst :,_,$@) -D WARMBOOT=1
		cp BUILD_spram_test/build.bin bin/bootloader.bin
		icemulti bin/bootloader.bin -o bin/multi.bin
		cp bin/multi.bin bin/header.bin
		truncate -s 4096 bin/header.bin
		iceprog bin/header.bin -o 1M
		cat bin/multi.bin bin/spram_show.bin bin/spram_fill.bin > bin/spram_test.bin
		iceprog bin/spram_test.bin

bram_test: ../fire-v/spark.ice
		make -C bram_fill
		make -C bram_show
		./compile.sh
		silice-make.py --no_program -s ../fire-v/spark.ice -b icebreaker -p basic,spiflash -o BUILD_$(subst :,_,$@) -D WARMBOOT=1
		cp BUILD_bram_test/build.bin bin/bootloader.bin
		icemulti bin/bootloader.bin -o bin/multi.bin
		cp bin/multi.bin bin/header.bin
		truncate -s 4096 bin/header.bin
		iceprog bin/header.bin -o 1M
		cat bin/multi.bin bin/bram_show.bin bin/bram_fill.bin > bin/bram_test.bin
		iceprog bin/bram_test.bin

clean:
	rm -rf BUILD_*

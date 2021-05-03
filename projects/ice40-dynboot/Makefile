
icebreaker: ../fire-v/spark.ice
		# make -C blinky_reboot
		./compile.sh
		silice-make.py --no_program -s ../fire-v/spark.ice -b $@ -p basic,spiflash -o BUILD_$(subst :,_,$@) -D WARMBOOT=1
		icemulti BUILD_icebreaker/build.bin -o multi.bin
		cp multi.bin header.bin
		truncate -s 4096 header.bin
		iceprog header.bin -o 1M
		cat multi.bin bin/blinky* > package.bin
		iceprog package.bin

clean:
	rm -rf BUILD_*


icebreaker: ../fire-v/spark.ice
		silice-make.py --no_program -s ../fire-v/spark.ice -b $@ -p basic,spiflash -o BUILD_$(subst :,_,$@) -D WARMBOOT=1

clean:
	rm -rf BUILD_*

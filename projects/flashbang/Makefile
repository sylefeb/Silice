
.DEFAULT: ../fire-v/spark.si firmware.c
		./compile.sh
		silice-make.sh -s ../fire-v/spark.si -b $@ -p basic,spiflash,uart -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: ../fire-v/spark.si firmware.c
		./compile.sh
		silice-make.sh -s ../fire-v/spark.si -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*


.DEFAULT: stream.si
		silice-make.py -s stream.si -b $@ -p basic,qspiflash,uart -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: stream.si
		mkdir -p BUILD_$(subst :,_,$@)
		cp W25Q128JVxIM/*.TXT BUILD_$(subst :,_,$@)/
		silice-make.py -s stream.si -b icarus -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: stream.si
		touch data.raw
		silice-make.py -s stream.si -b verilator -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

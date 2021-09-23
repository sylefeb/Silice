
.DEFAULT: stream.ice
		silice-make.py -s stream.ice -b $@ -p basic,qspiflash,uart -o BUILD_$(subst :,_,$@) -t shell

icarus: stream.ice
		mkdir -p BUILD_$(subst :,_,$@)
		cp W25Q128JVxIM/*.TXT BUILD_$(subst :,_,$@)/
		silice-make.py -s stream.ice -b icarus -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: stream.ice
		silice-make.py -s stream.ice -b verilator -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

stream: stream.ice
		mkdir -p BUILD_$(subst :,_,$@)
		cp W25Q128JVxIM/*.TXT BUILD_$(subst :,_,$@)/
		silice-make.py -s stream.ice -b icarus -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

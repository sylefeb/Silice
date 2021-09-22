
.DEFAULT: stream.ice
		silice-make.py -s stream.ice -b $@ -p basic,qspiflash,uart -o BUILD_$(subst :,_,$@) -t shell

icarus: main.ice
		mkdir -p BUILD_$(subst :,_,$@)
		cp W25Q128JVxIM/*.TXT BUILD_$(subst :,_,$@)/
		silice-make.py -s main.ice -b icarus -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: main.ice
		silice-make.py -s main.ice -b verilator -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

stream: stream.ice
		mkdir -p BUILD_$(subst :,_,$@)
		cp W25Q128JVxIM/*.TXT BUILD_$(subst :,_,$@)/
		silice-make.py -s stream.ice -b icarus -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

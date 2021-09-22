
.DEFAULT: main.ice
		silice-make.py -s main.ice -b $@ -p basic,qspiflash,uart -o BUILD_$(subst :,_,$@) -t shell

alt: alternative.ice
		silice-make.py -s alternative.ice -b icebreaker -p basic,qspiflash,uart -o BUILD_icebreaker -t shell

icarus: alternative.ice
		mkdir -p BUILD_$(subst :,_,$@)
		cp W25Q128JVxIM/*.TXT BUILD_$(subst :,_,$@)/
		silice-make.py -s alternative.ice -b icarus -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: main.ice
		silice-make.py -s main.ice -b verilator -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

stream: stream.ice
		mkdir -p BUILD_$(subst :,_,$@)
		cp W25Q128JVxIM/*.TXT BUILD_$(subst :,_,$@)/
		silice-make.py -s stream.ice -b icarus -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

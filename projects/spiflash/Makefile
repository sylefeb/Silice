
.DEFAULT: stream.si
		silice-make.py -s stream.si -b $@ -p basic,qspiflash,uart -o BUILD_$(subst :,_,$@) -t shell $(ARGS)

test: test.si
		silice-make.py -s test.si -b icebreaker -p basic,qspiflash,uart -o BUILD_icebreaker -t shell

icarus: stream.si
		mkdir -p BUILD_$(subst :,_,$@)
		cp W25Q128JVxIM/*.TXT BUILD_$(subst :,_,$@)/
		silice-make.py -s stream.si -b icarus -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: stream.si
		silice-make.py -s stream.si -b verilator -p basic -o BUILD_$(subst :,_,$@) $(ARGS)


.DEFAULT: xfer.si
		silice-make.sh -s xfer.si -b $@ -p basic,qspiflash,uart -o BUILD_$(subst :,_,$@) $(ARGS)

brot: xfer.si
		silice-make.sh -s xfer.si -b $@ -p basic,pmod_dspi,uart2 -o BUILD_$(subst :,_,$@) $(ARGS)

brot_uart2_mmod: xfer.si
		silice-make.sh -s xfer.si -b brot -p basic,uart2,spiflash_dspi -o BUILD_$(subst :,_,$@) $(ARGS)

#icebreaker: xfer.si
#		silice-make.sh -s xfer.si -b $@ -p basic,pmod_dspi,uart -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: stream.si
		mkdir -p BUILD_$(subst :,_,$@)
		cp W25Q128JVxIM/*.TXT BUILD_$(subst :,_,$@)/
		silice-make.sh -s stream.si -b icarus -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

verilator: stream.si
		touch data.raw
		silice-make.sh -s stream.si -b verilator -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

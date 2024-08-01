SERIAL_PORT ?= COM13

icestick: main.si
	silice-make.py -s main.si -b icestick -p basic,pmod_qqspi,spiscreen_extra -o BUILD_$(subst :,_,$@) -D SIM_SB_IO=1 -t shell -a force-reset-init $(ARGS)

verilator: main.si data.raw
		silice-make.py -s main.si -b $@ -p basic,spiscreen -o BUILD_$(subst :,_,$@) -t shell $(ARGS)

clean:
	rm -rf BUILD_*

data.raw: make_data.si
		silice-make.py -s make_data.si -b verilator -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

program_data: data.raw
		iceprog ../qpsram/bitstreams/icestick.bin
		sleep 1
		python  ../qpsram/xfer.py $(SERIAL_PORT) w 0 data.raw

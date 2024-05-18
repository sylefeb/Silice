SERIAL_PORT ?= COM13

icestick: main.si
	silice-make.py -s main.si -b icestick -p basic,basic,uart,pmod_qqspi,spiscreen_extra -o BUILD_$(subst :,_,$@)  -t shell $(ARGS)
	# -D SIM_SB_IO=1

tt: main.si
	silice-make.py -s main.si -b icestick -p basic,basic,uart,pmod_qqspi,spiscreen_extra -o BUILD_$(subst :,_,$@)  -t shell $(ARGS) -D SIM_SB_IO=1,NO_SERIAL=1

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

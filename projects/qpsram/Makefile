mch2022: xfer.si
	silice-make.py -s xfer.si -b $@ -p basic,uart,psram -o BUILD_$(subst :,_,$@) $(ARGS)

icebreaker: xfer.si
	silice-make.py -s xfer.si -b $@ -p basic,uart,pmod_qqspi -o BUILD_$(subst :,_,$@) $(ARGS)

icestick: xfer.si
	silice-make.py -s xfer.si -b $@ -p basic,uart,pmod_qqspi -o BUILD_$(subst :,_,$@) $(ARGS)

ecpix5: xfer.si
	silice-make.py -s xfer.si -b $@ -p basic,uart,pmod_qqspi -o BUILD_$(subst :,_,$@) $(ARGS)

ulx3s: xfer.si
	silice-make.py -s xfer.si -b $@ -p basic,uart,pmod_qqspi -o BUILD_$(subst :,_,$@) $(ARGS)

brot: xfer.si
	silice-make.py -s xfer.si -b brot -p basic,uart,qpsram -o BUILD_$(subst :,_,$@) $(ARGS)

brot2: xfer.si
	silice-make.py -s xfer.si -b brot -p basic,uart2,qpsram,sdcard -o BUILD_$(subst :,_,$@) $(ARGS)

musbx: xfer.si
	silice-make.py -s xfer.si -b musbx -p basic,uart2_rx_only,qpsram,sdcard -DMUSBX_V4=1 -o BUILD_$(subst :,_,$@) $(ARGS)

musbx_v3: xfer.si
	silice-make.py -s xfer.si -b musbx -p basic,uart2,qpsram,sdcard -o BUILD_$(subst :,_,$@) $(ARGS)

icarus: xfer.si
	silice-make.py -s xfer.si -b $@ -p basic -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*

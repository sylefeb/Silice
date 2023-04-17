mch2022: xfer.si
	silice-make.py -s xfer.si -b $@ -p basic,uart,psram -o BUILD_$(subst :,_,$@) $(ARGS)

icebreaker: xfer.si
	silice-make.py -s xfer.si -b $@ -p basic,uart,pmod_qqspi -o BUILD_$(subst :,_,$@) $(ARGS)

icestick: xfer.si
	silice-make.py -s xfer.si -b $@ -p basic,uart,pmod_qqspi -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*

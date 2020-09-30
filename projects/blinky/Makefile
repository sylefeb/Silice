
.DEFAULT: blinky.ice
ifdef tool
		../../bin/silice-make.py -s blinky.ice -b $@ -p basic -o BUILD_$(subst :,_,$@) -t $(tool)
else
		../../bin/silice-make.py -s blinky.ice -b $@ -p basic -o BUILD_$(subst :,_,$@)
endif

clean:
	rm -rf BUILD_*

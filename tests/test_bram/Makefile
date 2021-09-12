
.DEFAULT: bram.ice
ifdef tool
		silice-make.py -s bram.ice -b $@ -p basic -o BUILD_$(subst :,_,$@) -t $(tool)
else
		silice-make.py -s bram.ice -b $@ -p basic -o BUILD_$(subst :,_,$@)
endif

clean:
	rm -rf BUILD_*

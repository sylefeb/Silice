
.DEFAULT: inout.ice
ifdef tool
		silice-make.py -s inout.ice -b $@ -p basic,pmod -o BUILD_$(subst :,_,$@) -t $(tool)
else
		silice-make.py -s inout.ice -b $@ -p basic,pmod -o BUILD_$(subst :,_,$@)
endif

clean:
	rm -rf BUILD_*

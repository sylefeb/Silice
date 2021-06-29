.DEFAULT: main.ice
ifdef tool
		silice-make.py -s main.ice -b $@ -p basic,pmod -o BUILD_$(subst :,_,$@) -t $(tool)
else
		silice-make.py -s main.ice -b $@ -p basic,pmod -o BUILD_$(subst :,_,$@)
endif

clean:
	rm -rf BUILD_*

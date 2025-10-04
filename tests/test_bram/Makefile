
.DEFAULT: bram.si
ifdef tool
		silice-make.sh -s bram.si -b $@ -p basic -o BUILD_$(subst :,_,$@) -t $(tool)
else
		silice-make.sh -s bram.si -b $@ -p basic -o BUILD_$(subst :,_,$@)
endif

clean:
	rm -rf BUILD_*

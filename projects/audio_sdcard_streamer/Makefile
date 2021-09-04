
.DEFAULT: main.ice
		silice-make.py -s main.ice -b $@ -p basic,sdcard,audio -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*

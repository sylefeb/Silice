
.DEFAULT: main.si
		silice-make.py -s main.si -b $@ -p basic,sdcard,audio -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*


.DEFAULT: main.si
		silice-make.sh -s main.si -b $@ -p basic,sdcard,audio -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*

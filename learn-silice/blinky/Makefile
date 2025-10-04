
.DEFAULT: $(file)
		silice-make.sh -s $(file) -b $@ -p basic -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*

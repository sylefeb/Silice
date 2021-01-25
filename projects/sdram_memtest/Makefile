
.DEFAULT: sdram_memtest.ice
ifdef tool
		silice-make.py -s sdram_memtest.ice -b $@ -p basic,sdram -o BUILD_$(subst :,_,$@) -t $(tool)
else
		silice-make.py -s sdram_memtest.ice -b $@ -p basic,sdram -o BUILD_$(subst :,_,$@) 
endif
    
icarus: sdram_memtest.ice
		silice-make.py -s sdram_memtest.ice -b $@ -p basic -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*

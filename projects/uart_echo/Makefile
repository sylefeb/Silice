
.DEFAULT: uart_echo.si
		silice-make.sh -s uart_echo.si -b $@ -p basic,uart -o BUILD_$(subst :,_,$@) $(ARGS)

de10nano: uart_echo.si
		silice-make.sh -s uart_echo.si -b $@ -p basic,uart -o BUILD_$(subst :,_,$@) $(ARGS)

brot: uart_echo.si
		silice-make.sh -s uart_echo.si -b $@ -p basic,uart2,sdcard -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*

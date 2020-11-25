
.DEFAULT: uart_echo.ice
		silice-make.py -s uart_echo.ice -b $@ -p basic,uart -o BUILD_$(subst :,_,$@)

de10nano: uart_echo.ice
		silice-make.py -s uart_echo.ice -b $@ -p basic,uart2 -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*

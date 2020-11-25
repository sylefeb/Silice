
.DEFAULT: uart_echo.ice
		silice-make.py -s uart_echo.ice -b $@ -p basic,uart -o BUILD_$(subst :,_,$@)

de10nano: uart_echo.ice
		silice-make.py -s uart_echo.ice -b $@ -p basic,uart2 -o BUILD_$(subst :,_,$@)

ulx3s_uart2: uart_echo.ice
		silice-make.py -s uart_echo.ice -b ulx3s -p basic,uart2,gpio -o BUILD_$(subst :,_,$@)

clean:
	rm -rf BUILD_*

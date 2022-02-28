
.DEFAULT: uart_echo.si
		silice-make.py -s uart_echo.si -b $@ -p basic,uart -o BUILD_$(subst :,_,$@) $(ARGS)

de10nano: uart_echo.si
		silice-make.py -s uart_echo.si -b $@ -p basic,uart2 -o BUILD_$(subst :,_,$@) $(ARGS)

clean:
	rm -rf BUILD_*

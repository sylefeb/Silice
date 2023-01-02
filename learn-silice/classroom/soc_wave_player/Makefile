FIRMWARE ?= test_hello_world
BOARD ?= ulx3s

step0: step0.si
	make -C firmware $(FIRMWARE)
ifeq ($(BOARD),verilator)
	silice-make.py -s $@.si -b $(BOARD) -p basic -o BUILD_$(subst :,_,$@) $(ARGS)
else
	silice-make.py -s $@.si -b $(BOARD) -p basic -o BUILD_$(subst :,_,$@) $(ARGS)
endif

step0.si : main.si
	python ../tools/solutions.py > $@

step1: step1.si
	make -C firmware $(FIRMWARE)
ifeq ($(BOARD),verilator)
	silice-make.py -s $@.si -b $(BOARD) -p basic -o BUILD_$(subst :,_,$@) $(ARGS)
else
	silice-make.py -s $@.si -b $(BOARD) -p basic,audio -o BUILD_$(subst :,_,$@) $(ARGS)
endif

step1.si : main.si
	python ../tools/solutions.py -s LED > $@

step2: step2.si
	make -C firmware $(FIRMWARE)
ifeq ($(BOARD),verilator)
	silice-make.py -s $@.si -b $(BOARD) -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)
else
	silice-make.py -s $@.si -b $(BOARD) -p basic,audio,oled -o BUILD_$(subst :,_,$@) $(ARGS)
endif

step2.si : main.si
	python ../tools/solutions.py -s LED,AUDIO,OLED > $@

step3: step3.si
	make -C firmware $(FIRMWARE)
ifeq ($(BOARD),verilator)
	silice-make.py -s $@.si -b $(BOARD) -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)
else
	silice-make.py -s $@.si -b $(BOARD) -p basic,audio,oled,buttons -o BUILD_$(subst :,_,$@) $(ARGS)
endif

step3.si : main.si
	python ../tools/solutions.py -s LED,AUDIO,OLED > $@

step4: step4.si
	make -C firmware $(FIRMWARE)
ifeq ($(BOARD),verilator)
	silice-make.py -s $@.si -b $(BOARD) -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)
else
	silice-make.py -s $@.si -b $(BOARD) -p basic,audio,oled,buttons,sdcard -o BUILD_$(subst :,_,$@) $(ARGS)
endif

step4.si : main.si
	python ../tools/solutions.py -s LED,AUDIO,OLED,BTN,SD > $@

step5: step5.si
	make -C firmware $(FIRMWARE)
ifeq ($(BOARD),verilator)
	silice-make.py -s $@.si -b $(BOARD) -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)
else
	silice-make.py -s $@.si -b $(BOARD) -p basic,audio,oled,buttons,sdcard -o BUILD_$(subst :,_,$@) $(ARGS)
endif

step5.si : main.si
	python ../tools/solutions.py -s LED,AUDIO,OLED,BTN,SD,STREAM > $@

step6: step6.si
	make -C firmware $(FIRMWARE)
ifeq ($(BOARD),verilator)
	silice-make.py -s $@.si -b $(BOARD) -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)
else
	silice-make.py -s $@.si -b $(BOARD) -p basic,audio,oled,buttons,sdcard -o BUILD_$(subst :,_,$@) $(ARGS)
endif

step6.si : main.si
	python ../tools/solutions.py -s LED,AUDIO,OLED,BTN,SD,STREAM > $@

final: final.si
	make -C firmware $(FIRMWARE)
ifeq ($(BOARD),verilator)
	silice-make.py -s $@.si -b $(BOARD) -p basic,oled -o BUILD_$(subst :,_,$@) $(ARGS)
else
	silice-make.py -s $@.si -b $(BOARD) -p basic,audio,oled,buttons,sdcard -o BUILD_$(subst :,_,$@) $(ARGS)
endif

final.si : main.si
	python ../tools/solutions.py -s LED,AUDIO,OLED,BTN,SD,STREAM,PWM > $@

clean:
	make -C firmware clean
	rm -rf BUILD_*
	rm -f *.lpp

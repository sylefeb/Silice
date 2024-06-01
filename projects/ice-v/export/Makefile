
M_icev_cpu.v: export.si
		# export the controller to verilog
		silice export.si --output M_icev_cpu.v \
			--export icev_cpu \
			--frameworks_dir ../../../frameworks/ \
			--framework ../../../frameworks/boards/bare/bare.v
			-D ICE40=1 \
			-D ICESTICK=1 \
			-D MEM_ADDR_SIGNED=0 \
		# clean up compiler log files
		rm *.log *.lpp

clean:
	rm -rf build.* M_icev_cpu.* *.lpp abc.history

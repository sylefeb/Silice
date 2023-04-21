
M_qpsram_ram.v: export.si
		# export the controller to verilog
		silice export.si --output M_qpsram_ram.v \
			--export qpsram_ram \
			--frameworks_dir ../../../frameworks/ \
			--framework ../../../frameworks/boards/bare/bare.v
		# clean up compiler log files
		rm *.log *.lpp

clean:
	rm -rf build.* M_qpsram_ram.* *.lpp abc.history


sdram_controller.v: export_controller.ice
		# export the controller to verilog
		silice export_controller.ice --output sdram_controller.v \
			--export sdram_controller_autoprecharge_r16_w16 \
			--frameworks_dir ../../frameworks/ \
			--framework ../../frameworks/boards/bare/bare.v \
			-P SD_DONE_SIGNED=0 \
			-P SD_DONE_WIDTH=1 \
			-P SD_DONE_INIT=0 \
			-P SD_DATA_OUT_SIGNED=0 \
			-P SD_DATA_OUT_WIDTH=16 \
			-P SD_DATA_OUT_INIT=0 \
			-P SD_IN_VALID_SIGNED=0 \
			-P SD_IN_VALID_WIDTH=1 \
			-P SD_IN_VALID_INIT=0 \
			-P SD_WMASK_SIGNED=0 \
			-P SD_WMASK_WIDTH=1 \
			-P SD_WMASK_INIT=0 \
			-P SD_DATA_IN_SIGNED=0 \
			-P SD_DATA_IN_WIDTH=16 \
			-P SD_DATA_IN_INIT=0 \
			-P SD_RW_SIGNED=0 \
			-P SD_RW_WIDTH=1 \
			-P SD_RW_INIT=1 \
			-P SD_ADDR_SIGNED=0 \
			-P SD_ADDR_WIDTH=26 \
			-P SD_ADDR_INIT=0
		# clean up compiler log files
		rm sdram_controller.v.*

build.bit: sdram_controller.v
		# synthesize example for ULX3S
		yosys -p 'scratchpad -copy abc9.script.flow3 abc9.script; synth_ecp5 -abc9 -json build.json' sdram_example.v
		nextpnr-ecp5 --85k --package CABGA381 --freq 25 --json build.json --textcfg build.config --lpf ../../frameworks/boards/ulx3s/ulx3s.lpf --timing-allow-fail -r
		ecppack --compress --svf-rowsize 100000 --svf build.svf build.config build.bit

ulx3s: build.bit
		openFPGALoader -b ulx3s build.bit

clean:
	rm -rf build.* sdram_controller.* *.lpp abc.history

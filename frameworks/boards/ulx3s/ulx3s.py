import os
import sys

import yowasp_silice
import yowasp_yosys
import yowasp_nextpnr_ecp5

print("+ Silice bin directory       : ",os.getenv("SILICE_DIR",""))
print("+ Build output directory     : ",os.getenv("BUILD_DIR",""))
print("+ Silice frameworks directory: ",os.getenv("FRAMEWORKS_DIR",""))
print("+ Frameworks file            : ",os.getenv("FRAMEWORK_FILE",""))
print("+ Board directory            : ",os.getenv("BOARD_DIR",""))
print("+ Board variant              : ",os.getenv("BOARD_VARIANT",""))
print("+ Top module                 : ",os.getenv("SILICE_TOP",""))

# go inside the build directory
os.chdir(os.getenv("BUILD_DIR",""))

# call silice
args = sys.argv[1:]
yowasp_silice.run_silice(["--frameworks_dir",os.getenv("FRAMEWORKS_DIR",""),
                          "--framework",os.getenv("FRAMEWORK_FILE",""),
                          *silice_args.split(" ")])
# call yosys
yosys_args = ['-p','read_verilog -sv out.v','-p','scratchpad -copy abc9.script.flow3 abc9.script; synth_ecp5 -abc9 -json build.json -top top']
print(yosys_args)
yowasp_yosys.run_yosys(yosys_args)

# call nextpnr
nextpnr_args=['--' + os.getenv("BOARD_VARIANT",""),'--package','CABGA381','--freq','25','--json','build.json','--textcfg','build.config','--lpf',os.getenv("BOARD_DIR","")+'/ulx3s.lpf','--timing-allow-fail','-r']
yowasp_nextpnr_ecp5.run_nextpnr_ecp5(nextpnr_args)

# call icepack
yowasp_nextpnr_ecp5.run_ecppack(['--compress','--svf-rowsize','100000','--svf','build.svf','build.config','build.bit'])

print("---")
print("Bitstream produced in " + os.getenv("BUILD_DIR","") + "/build.bit.")

yowasp_silice.serve_openFPGALoader('ulx3s',"build.bit")

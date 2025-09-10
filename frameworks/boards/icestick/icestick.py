import os
import sys

import yowasp_silice
import yowasp_yosys
import yowasp_nextpnr_ice40

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
yosys_args = ['-l','yosys.log','-p',"read_verilog -sv out.v",'-p',"synth_ice40 -relut -top top -json build.json"]
print(yosys_args)
yowasp_yosys.run_yosys(yosys_args)

# call nextpnr
nextpnr_args=['--force','--hx1k','--json','build.json','--pcf',os.getenv("BOARD_DIR","") + '/icestick.pcf','--asc','build.asc','--package','tq144','--freq','12']
yowasp_nextpnr_ice40.run_nextpnr_ice40(nextpnr_args)

# call icepack
yowasp_nextpnr_ice40.run_icepack(['build.asc','build.bin'])

print("---")
print("Bitstream produced in " + os.getenv("BUILD_DIR","") + "/build.bin.")

yowasp_silice.serve_openFPGALoader('ice40_generic',"build.bin")

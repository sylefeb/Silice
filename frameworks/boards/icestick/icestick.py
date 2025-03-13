import yowasp_silice
import yowasp_yosys
import yowasp_nextpnr_ice40

# test Silice
yowasp_silice.run_silice(["--help"])
# test Yosys
yowasp_yosys.run_yosys(["--help"])
# test Nextpnr
yowasp_nextpnr_ice40.run_nextpnr_ice40(["--help"])

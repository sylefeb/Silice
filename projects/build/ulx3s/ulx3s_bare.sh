DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../../bin/:$DIR/../../../tools/fpga-binutils/mingw32/bin/
export PYTHONHOME=/mingw32/bin
export PYTHONPATH=/mingw32/lib/python3.8/
export QT_QPA_PLATFORM_PLUGIN_PATH=/mingw32/share/qt5/plugins

rm buildb1*

silice -f ../../../frameworks/ulx3s.v $1 -o buildb1.v

# exit

yosys -p 'synth_ecp5 -abc9 -json buildb1.json' buildb1.v

nextpnr-ecp5 --85k --package CABGA381 --json buildb1.json --textcfg buildb1.config --lpf ulx3s.lpf --timing-allow-fail --freq 25

ecppack --compress --svf-rowsize 100000 --svf buildb1.svf buildb1.config buildb1.bit

fujprog buildb1.bit

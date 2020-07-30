DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../../bin/:$DIR/../../../tools/fpga-binutils/mingw64/bin/
export PYTHONHOME=/mingw64/bin
export PYTHONPATH=/mingw64/lib/python3.8/
export QT_QPA_PLATFORM_PLUGIN_PATH=/mingw64/share/qt5/plugins

rm buildb*

silice -f ../../../frameworks/ulx3s.v $1 -o buildb.v

# exit

# yosys -p 'synth_ecp5 -abc9 -top top -json buildb.json' buildb.v
yosys -p 'synth_ecp5 -top top -json buildb.json' buildb.v

nextpnr-ecp5 --85k --package CABGA381 --json buildb.json --textcfg buildb.config --lpf ulx3s.lpf --timing-allow-fail --freq 25

ecppack --compress --svf-rowsize 100000 --svf buildb.svf buildb.config buildb.bit

fujprog buildb.bit

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../../bin/:$DIR/../../../tools/fpga-binutils/mingw32/bin/
export PYTHONHOME=/mingw32/bin
export PYTHONPATH=/mingw32/lib/python3.8/
export QT_QPA_PLATFORM_PLUGIN_PATH=/mingw32/share/qt5/plugins

rm build*

silice -f ../../../frameworks/ulx3s.v $1 -o build.v

# exit

yosys -p 'synth_ecp5 -abc9 -top top -json build.json' build.v

nextpnr-ecp5 --85k --package CABGA381 --json build.json --textcfg build.config --lpf ulx3s.lpf --timing-allow-fail --freq 25

ecppack --svf-rowsize 100000 --svf build.svf build.config build.bit

fujprog build.bit

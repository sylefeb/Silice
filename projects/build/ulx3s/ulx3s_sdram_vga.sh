DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../../bin/:$DIR/../../../tools/fpga-binutils/mingw32/bin/
export PYTHONHOME=/mingw32/bin
export PYTHONPATH=/mingw32/lib/python3.8/
export QT_QPA_PLATFORM_PLUGIN_PATH=/mingw32/share/qt5/plugins

rm build1*

silice -f ../../../frameworks/ulx3s_sdram_vga.v $1 -o build1.v

# exit

yosys -p 'synth_ecp5 -abc9 -top top -json build1.json' build1.v

nextpnr-ecp5 --85k --package CABGA381 --json build1.json --textcfg build1.config --lpf ulx3s.lpf --timing-allow-fail --freq 25

ecppack --svf-rowsize 100000 --svf build1.svf build1.config build1.bit

fujprog build1.bit

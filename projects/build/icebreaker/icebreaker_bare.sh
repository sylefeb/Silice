#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../../bin/:$DIR/../../../tools/fpga-binutils/mingw32/bin/
export PYTHONHOME=/mingw32/bin
export PYTHONPATH=/mingw32/lib/python3.8/

rm build*

silice -f ../../../frameworks/icebreaker.v $1 -o build.v

# exit

yosys -q -p "synth_ice40 -json build.json" build.v
nextpnr-ice40 --up5k --package sg48 --freq 13 --json build.json --pcf icebreaker.pcf --asc build.asc
icepack build.asc build.bin

iceprog build.bin

#!/bin/bash

# credits: rob-ng15 -- see also https://github.com/rob-ng15/Silice-Playground

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../../bin/:$DIR/../../../tools/fpga-binutils/mingw32/bin/

rm build*

silice -f ../../../frameworks/fomu.v $1 -o build.v

yosys -D HACKER=1 -p 'synth_ice40 -top top -json build.json' build.v
nextpnr-ice40 --up5k --package uwg30 --opt-timing --pcf pcf/fomu-hacker.pcf --json build.json --asc build.asc
icepack build.asc build.bit
icetime -d up5k -mtr build.rpt build.asc
cp build.bit build.dfu
dfu-suffix -v 1209 -p 70b1 -a build.dfu

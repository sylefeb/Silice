#!/bin/bash
rm build*

silice -f frameworks/fomu.v $1 -o build.v

yosys -D HACKER=1 -p 'synth_ice40 -top top -json build.json' build.v
nextpnr-ice40 --up5k --package uwg30 --pcf pcf/fomu-hacker.pcf --json build.json --asc build.asc
icepack build.asc build.bit
cp build.bit build.dfu
dfu-suffix -v 1209 -p 70b1 -a build.dfu

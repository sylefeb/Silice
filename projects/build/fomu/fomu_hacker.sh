#!/bin/bash
rm build*

silice -f ../../../frameworks/fomu.v $1 -o build.v

yosys -D HACKER=1 -p 'synth_ice40 -top top -json build.json' build.v
nextpnr-ice40 --up5k --package uwg30 --pcf fomu-hacker.pcf --json build.json --asc build.asc
icepack build.asc build.bin
cp blink.bit blink.dfu
dfu-suffix -v 1209 -p 70b1 -a blink.dfu

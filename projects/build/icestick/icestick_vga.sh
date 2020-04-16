../../../bin/silice -f ../../../frameworks/icestick_vga.v $1 -o build.v
yosys -p 'synth_ice40 -top top -json build.json' build.v
nextpnr-ice40 --hx1k --json build.json --pcf ../../../frameworks/icestick.pcf --asc build.asc --gui
icepack build.asc build.bin
# iceprog build.bin

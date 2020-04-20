DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../../tools/fpga-binutils/mingw32/bin/

../../../bin/silice -f ../../../frameworks/icestick_vga.v $1 -o build.v
yosys -p 'synth_ice40 -top top -json build.json' build.v

if ! type "nextpnr-ice40" > /dev/null; then
  # try arachne-pnr instead
else
  nextpnr-ice40 --hx1k --json build.json --pcf ../../../frameworks/icestick.pcf --asc build.asc
fi

icepack build.asc build.bin
iceprog build.bin

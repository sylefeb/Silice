DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../../tools/fpga-binutils/mingw32/bin/

../../../bin/silice -f ../../../frameworks/icestick_vga.v $1 -o build.v

if ! type "nextpnr-ice40" > /dev/null; then
  # try arachne-pnr instead
  echo "nextpnr not found, trying arachnepnr instead"
  arachne-pnr -p ../../../frameworks/icestick.pcf build.blif -o build.txt
  icepack build.txt build.bin
else
  yosys -p 'synth_ice40 -top top -json build.json' build.v
  nextpnr-ice40 --hx1k --json build.json --pcf ../../../frameworks/icestick.pcf --asc build.asc
  icepack build.asc build.bin
fi

iceprog build.bin

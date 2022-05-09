#!/bin/bash

case "$(uname -s)" in
MINGW*|CYGWIN*)
SILICE_DIR=`cygpath $SILICE_DIR`
BUILD_DIR=`cygpath $BUILD_DIR`
FRAMEWORKS_DIR=`cygpath $FRAMEWORKS_DIR`
FRAMEWORK_FILE=`cygpath $FRAMEWORK_FILE`
BOARD_DIR=`cygpath $BOARD_DIR`
;;
*)
esac

echo "build script: SILICE_DIR     = $SILICE_DIR"
echo "build script: BUILD_DIR      = $BUILD_DIR"
echo "build script: BOARD_DIR      = $BOARD_DIR"
echo "build script: FRAMEWORKS_DIR = $FRAMEWORKS_DIR"
echo "build script: FRAMEWORK_FILE = $FRAMEWORK_FILE"

export PATH=$PATH:$SILICE_DIR/../tools/fpga-binutils/mingw64/bin/:$SILICE_DIR
case "$(uname -s)" in
MINGW*)
# export PYTHONHOME=/mingw64/bin
# export PYTHONPATH=/mingw64/lib/python3.8/
export QT_QPA_PLATFORM_PLUGIN_PATH=/mingw64/share/qt5/plugins
;;
*)
esac

cd $BUILD_DIR

rm build*

silice --frameworks_dir $FRAMEWORKS_DIR -f $FRAMEWORK_FILE -o build.v $1 "${@:2}"

if ! type "nextpnr-ice40" > /dev/null; then
  # try arachne-pnr instead
  echo "nextpnr-ice40 not found, trying arachne-pnr instead"
  yosys -q -p "synth_ice40 -blif build.blif -top top" build.v
  arachne-pnr -p $BOARD_DIR/icestick.pcf build.blif -o build.txt
  icepack build.txt build.bin
else
  yosys -l yosys.log -p 'synth_ice40 -relut -abc9 -top top -json build.json' build.v
  nextpnr-ice40 --force --hx1k --json build.json --pcf $BOARD_DIR/icestick.pcf --asc build.asc --package tq144 --freq 12
  icepack build.asc build.bin
fi

iceprog build.bin

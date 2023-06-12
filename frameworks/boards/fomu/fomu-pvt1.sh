#!/bin/bash

# credits: rob-ng15 -- see also https://github.com/rob-ng15/Silice-Playground

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

if [[ ! -z "${NO_BUILD}" ]]; then
  echo "Skipping build."
  exit
fi

cd $BUILD_DIR

rm build*

silice --frameworks_dir $FRAMEWORKS_DIR -f $FRAMEWORK_FILE -o build.v $1 "${@:2}"

yosys -D PVT=1 -p "read_verilog -sv build.v" -p 'synth_ice40 -dsp -top top -json build.json'

nextpnr-ice40 --up5k --freq 12 --package uwg30 --pcf $BOARD_DIR/fomu-pvt1.pcf --json build.json --asc build.asc

icepack -s build.asc build.bit
icetime -d up5k -mtr build.rpt build.asc

cp build.bit build.dfu
dfu-suffix -v 1209 -p 70b1 -a build.dfu

if [[ ! -z "${NO_PROGRAM}" ]]; then
  echo "Skipping prog."
  exit
fi

dfu-util -D build.dfu

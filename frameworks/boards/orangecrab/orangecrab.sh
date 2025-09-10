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

yosys -p "read_verilog -sv build.v" -p 'synth_ecp5 -abc9 -nowidelut -json build.json -top top'

nextpnr-ecp5 --25k --package CSFBGA285 --json build.json --textcfg build.config\
             --lpf $BOARD_DIR/pinout.lpf --timing-allow-fail --freq 38.8\
             --lpf-allow-unconstrained

ecppack --freq 38.8 --compress build.config build.bit

cp build.bit build.dfu
dfu-suffix -v 1209 -p 5af0 -a build.dfu
dfu-util -D build.dfu

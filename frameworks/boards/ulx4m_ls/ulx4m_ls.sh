#!/bin/bash

set -e

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

set +e
rm build*
set -e

silice --frameworks_dir $FRAMEWORKS_DIR -f $FRAMEWORK_FILE -o build.v $1 "${@:2}"

if [[ ! -z "${NO_BUILD}" ]]; then
  echo "Skipping build."
  exit
fi

yosys -p "read_verilog -sv build.v" -p 'scratchpad -copy abc9.script.flow3 abc9.script; synth_ecp5 -abc9 -json build.json -top top'

nextpnr-ecp5 --12k --package CABGA381 --freq 25 --json build.json --textcfg build.config --lpf $BOARD_DIR/ulx4m_ls.lpf --timing-allow-fail -r
# --seed 700001
# --seed 73
# --placer sa --starttemp 2 --cstrweight 20

ecppack --compress --svf-rowsize 100000 --svf build.svf build.config build.bit

openFPGALoader --dfu --vid 0x1d50 --pid 0x614b --altsetting 0 build.bit
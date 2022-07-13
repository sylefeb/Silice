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

if [[ ! -z "${NO_BUILD}" ]]; then
  echo "Skipping build."
  exit
fi

cd $BUILD_DIR

set +e
rm build*
set -e

silice --frameworks_dir $FRAMEWORKS_DIR -f $FRAMEWORK_FILE -o build.v $1 "${@:2}"

yosys -p "synth_ice40 -dsp -json build.json -abc9 -device u -top top" build.v
nextpnr-ice40 --up5k --freq 12 --package sg48 --json build.json --pcf $BOARD_DIR/mch2022.pcf --asc build.asc -r --timing-allow-fail

icepack -s build.asc build.bin

echo "========================================================="
echo "Upload the bitstream with:"
echo "    webusb_fpga.py BUILD_mch2022/build.bin"
echo ""
echo "(available at https://github.com/badgeteam/mch2022-tools)"
echo "========================================================="

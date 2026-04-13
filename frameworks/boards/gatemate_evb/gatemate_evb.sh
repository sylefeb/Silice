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

NEXTPNR_CMD=$(command -v nextpnr-himbaechel || command -v nextpnr-himbaechel-gatemate)

yosys -p "read_verilog -sv build.v" -p "synth_gatemate -top top -luttree -nomx8 ; write_json build.json"
"$NEXTPNR_CMD" --device=CCGM1A1 --json build.json --vopt out=build.txt --vopt ccf=$BOARD_DIR/gatemate_evb.ccf --router router2 --freq 10 --timing-allow-fail
gmpack --input build.txt --bit build.bit

if [[ ! -z "${NO_PROGRAM}" ]]; then
  echo "Skipping prog."
  exit
fi

openFPGALoader -b gatemate_evb_jtag build.bit

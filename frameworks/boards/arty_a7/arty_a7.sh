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

NEXTPNR_CMD=$(command -v nextpnr-himbaechel-xilinx || command -v nextpnr-himbaechel)

yosys -p "read_verilog -sv build.v" -p "synth_xilinx -top top -flatten -abc9 -arch xc7 ; write_json build.json"
"$NEXTPNR_CMD" --device=xc7a35tcsg324-1 --json build.json --vopt fasm=build.fasm --vopt xdc=$BOARD_DIR/arty_a7.xdc --router router2 --timing-allow-fail

source ~/.local/share/silice/.venv/bin/activate
export PYTHONPATH="$PYTHONPATH:/usr/local/share/nextpnr/prjxray/"
fasm2frames --db-root /usr/local/share/nextpnr/prjxray-db/artix7 --part xc7a35tcsg324-1 build.fasm > build.frames

xc7frames2bit --part_name xc7a35tcsg324-1 --frm_file build.frames --output_file build.bit --part_file /usr/local/share/nextpnr/prjxray-db/artix7/xc7a35tcsg324-1/part.yaml

if [[ ! -z "${NO_PROGRAM}" ]]; then
  echo "Skipping prog."
  exit
fi

openFPGALoader -b arty_a7_35t build.bit

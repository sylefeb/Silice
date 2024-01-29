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

# export PYTHONPATH=/mingw64/lib/python3.8/
# python -c 'import site; print(site.getsitepackages())'

silice --frameworks_dir $FRAMEWORKS_DIR -f $FRAMEWORK_FILE -o build.v $1 "${@:2}"
yosys -p "synth_gowin -json build.json -top top" build.v

pip install apycula
# nextpnr should be compiled using 'humbaechel', see the discussion here: https://github.com/YosysHQ/apicula/issues/220#issuecomment-1876682997
# the following command is from apicula/examples/himbaechel/Makefile.himbaechel
nextpnr-himbaechel --json build.json --write outbuild.json --device GW2AR-LV18QN88C8/I7 --vopt family=GW2A-18C --vopt cst=$BOARD_DIR/tang_nano_20k.cst
gowin_pack -d GW2A-18 -o pack.fs outbuild.json

dos2unix pack.fs
openFPGALoader -b tangnano20k pack.fs

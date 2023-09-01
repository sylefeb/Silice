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

export PATH=$PATH:$SILICE_DIR:$SILICE_DIR/../tools/fpga-binutils/mingw64/bin/
case "$(uname -s)" in
MINGW*)
# export PYTHONHOME=/mingw64/bin
# export PYTHONPATH=/mingw64/lib/python3.8/
export QT_QPA_PLATFORM_PLUGIN_PATH=/mingw64/share/qt5/plugins
;;
*)
esac

cd $BUILD_DIR

rm build* trace.fst trace.fst.hier

silice --frameworks_dir $FRAMEWORKS_DIR -f $FRAMEWORK_FILE -o build.v $1 "${@:2}"

iverilog -g2012 -o build -pfileline=1 build.v
vvp build -fst

echo "===================================="
echo "Visualize the simulation trace with:"
echo "    gtkwave BUILD_icarus/trace.fst"
echo "===================================="

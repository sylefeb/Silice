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

if hash make 2>/dev/null; then
  export MAKE=make
else
  export MAKE=mingw32-make  
fi

export PATH=$PATH:$SILICE_DIR/../tools/fpga-binutils/mingw64/bin/:$SILICE_DIR

if [[ -z "${VERILATOR_ROOT}" ]]; then
case "$(uname -s)" in
Linux)
unset VERILATOR_ROOT
;;
*)
export VERILATOR_ROOT=$SILICE_DIR/../tools/fpga-binutils/mingw64/
;;
esac
echo "VERILATOR_ROOT is set to ${VERILATOR_ROOT}"
else
echo "VERILATOR_ROOT already defined, using its value"
fi

u=$(echo "$1" | sed s:/:__:g | tr -d ".")

echo "using directory $u"

cd $BUILD_DIR

silice --frameworks_dir $FRAMEWORKS_DIR -f $FRAMEWORK_FILE -o build.v $1 "${@:2}"

if [[ -z "${VGA}" ]] && [[ -z "${SDRAM}" ]]; then
VERILATOR_LIB="verilator_bare"
else
VERILATOR_LIB="verilator_vga"
fi

echo "using verilator framework $VERILATOR_LIB"

verilator -Wno-PINMISSING -Wno-WIDTH -O3 -cc build.v --report-unoptflat --top-module top
cd obj_dir
$MAKE -f Vtop.mk
$MAKE -f Vtop.mk $SILICE_DIR/../frameworks/verilator/$VERILATOR_LIB.o verilated.o 
g++ -fpack-struct=8 -O3 $SILICE_DIR/../frameworks/verilator/$VERILATOR_LIB.o verilated.o Vtop__ALL.a $SILICE_DIR/../frameworks/verilator/libverilator_silice.a -o ../run_simul
cd ..

./run_simul

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

case "$(uname -s)" in
MINGW*) GL_LIB="opengl32" ;;
*) GL_LIB="GL" ;;
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

LIBSL_DIR=$SILICE_DIR/../src/libs/LibSL-small/src/LibSL/
VERILATOR_LIB_DIR=$SILICE_DIR/../frameworks/verilator/

if [[ -z "${VGA}" ]] && [[ -z "${SDRAM}" ]]; then
VERILATOR_LIB="verilator_bare"
VERILATOR_LIB_SRC="$VERILATOR_LIB_DIR/verilator_bare.cpp"
else
if [[ -z "${SDRAM}" ]]; then
VERILATOR_LIB="verilator_vga"
VERILATOR_LIB_SRC="$VERILATOR_LIB_DIR/verilator_vga.cpp $VERILATOR_LIB_DIR/vga_display.cpp $VERILATOR_LIB_DIR/VgaChip.cpp $LIBSL_DIR/Image/ImageFormat_TGA.cpp $LIBSL_DIR/Image/Image.cpp $LIBSL_DIR/Image/tga.cpp $LIBSL_DIR/Math/Vertex.cpp $LIBSL_DIR/Math/Math.cpp $LIBSL_DIR/StlHelpers/StlHelpers.cpp $LIBSL_DIR/CppHelpers/CppHelpers.cpp $LIBSL_DIR/System/System.cpp"
else
VERILATOR_LIB="verilator_vga_sdram"
VERILATOR_LIB_SRC="$VERILATOR_LIB_DIR/verilator_vga_sdram.cpp $VERILATOR_LIB_DIR/vga_display.cpp $VERILATOR_LIB_DIR/sdr_sdram.cpp $VERILATOR_LIB_DIR/VgaChip.cpp $LIBSL_DIR/Image/ImageFormat_TGA.cpp $LIBSL_DIR/Image/Image.cpp $LIBSL_DIR/Image/tga.cpp $LIBSL_DIR/Math/Vertex.cpp $LIBSL_DIR/Math/Math.cpp $LIBSL_DIR/StlHelpers/StlHelpers.cpp $LIBSL_DIR/CppHelpers/CppHelpers.cpp $LIBSL_DIR/System/System.cpp"
fi
fi

echo "using verilator framework $VERILATOR_LIB"

verilator -Wno-PINMISSING -Wno-WIDTH -O3 -cc build.v --report-unoptflat --top-module top --exe  $VERILATOR_LIB_SRC -CFLAGS "-O3 -I$SILICE_DIR/../frameworks/verilator/ -I$SILICE_DIR/../src/libs/LibSL-small/src/  -I$SILICE_DIR/../src/libs/LibSL-small/src/LibSL/ -DNO_SHLWAPI" -LDFLAGS "-lfreeglut -l$GL_LIB"
cd obj_dir
$MAKE -f Vtop.mk -j$(nproc)
cd ..

./obj_dir/Vtop

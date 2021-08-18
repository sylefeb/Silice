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
# export PYTHONHOME=/mingw64/bin
# export PYTHONPATH=/mingw64/lib/python3.8/
export QT_QPA_PLATFORM_PLUGIN_PATH=/mingw64/share/qt5/plugins

cd $BUILD_DIR

rm -rf build* *.rdf *.sty impl

silice --frameworks_dir $FRAMEWORKS_DIR -f $FRAMEWORK_FILE -o build.v $1 "${@:2}"

cat << EOF > build.tcl
prj_create -name "build" -impl "impl" -dev LIFCL-40-9BG400C
prj_set_impl_opt {include path} {""}
prj_add_source "build.v" -work work
prj_add_source "$BOARD_DIR/crosslink_nx_evn.pdc" -work work
prj_set_impl_opt top "top"
prj_save
prj_run Synthesis -impl impl -forceOne
prj_run Map -impl impl
prj_run PAR -impl impl
prj_run Export -impl impl -task Bitgen
prj_close
EOF

radiantc build.tcl > toto.log 2>&1 # toto.log - French touch ;-)

openFPGALoader impl/build_impl.bit

#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

export YOSYSHQ_ROOT=$DIR/oss-cad-suite

export SSL_CERT_FILE=%YOSYSHQ_ROOT%etc\cacert.pem

export PATH=$YOSYSHQ_ROOT/share/verilator/bin/:$YOSYSHQ_ROOT/bin:$YOSYSHQ_ROOT/lib:$PATH
# export PATH=$YOSYSHQ_ROOT/bin:$YOSYSHQ_ROOT/lib:$YOSYSHQ_ROOT/py3bin:$PATH
# export PYTHON_EXECUTABLE=$YOSYSHQ_ROOT/py3bin/python3
export QT_PLUGIN_PATH=$YOSYSHQ_ROOT/lib/qt5/plugins

export GTK_EXE_PREFIX=$YOSYSHQ_ROOT
export GTK_DATA_PREFIX=$YOSYSHQ_ROOT
export GDK_PIXBUF_MODULEDIR=$YOSYSHQ_ROOT/lib/gdk-pixbuf-2.0/2.10.0/loaders
export GDK_PIXBUF_MODULE_FILE=$YOSYSHQ_ROOT/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache

gdk-pixbuf-query-loaders.exe --update-cache

export OPENFPGALOADER_SOJ_DIR=$YOSYSHQ_ROOT/share/openFPGALoader

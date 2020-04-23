#!/bin/bash

mkdir BUILD
cd BUILD
export VERILATOR_ROOT=`verilator --getenv VERILATOR_ROOT`
cmake -G "Unix Makefiles" ../frameworks/verilator/
make install
cd ..
rm -rf BUILD

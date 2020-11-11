#!/bin/bash

git submodule init
git submodule update

mkdir BUILD
cd BUILD

mkdir verilator-framework
cd verilator-framework

export VERILATOR_ROOT=`verilator --getenv VERILATOR_ROOT`
cmake -G "Unix Makefiles" ../../frameworks/verilator/
make install

cd ..

cd ..

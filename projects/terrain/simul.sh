#!/bin/bash
export DIR=`pwd`
echo $DIR
pushd .
cd ../fire-v/
./compile_c_blaze_native.sh $DIR/firmware_simul.c 
cp build/code*.hex $DIR/build/
popd

make clean
make verilator

#!/bin/bash
export DIR=`pwd`
echo $DIR
rm build/code*.hex
pushd .
cd ../fire-v/
rm build/code*.hex
./compile_to_spark.sh $DIR/firmware.c 
# ./compile_to_spark.sh smoke/tests/leds.c
cp build/code*.hex $DIR/build/
popd

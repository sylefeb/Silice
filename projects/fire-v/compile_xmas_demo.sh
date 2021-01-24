#!/bin/bash

rm data.img sdcard.img

./compile_dual.sh tests/c/xmas.c

rm -rf BUILD_verilator/

# make verilator -f Makefile.dual
make ulx3s -f Makefile.dual
# make sdcard

cat data.img tests/c/xmas_bkg.rawraw tests/c/silence.raw tests/c/cpu0.raw tests/c/cpu1.raw tests/c/xmas1.raw tests/c/xmas2.raw tests/c/friend.raw > sdcard.img

#!/bin/bash

./compile_dual.sh tests/c/audio.c

make ulx3s -f Makefile.dual

cat data.img tests/c/left.raw tests/c/right.raw tests/c/speak_l.raw tests/c/speak_r.raw tests/c/hi_sorry.raw tests/c/come_on.raw tests/c/he_is_right.raw > sdcard.img

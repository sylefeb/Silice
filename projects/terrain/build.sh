#!/bin/bash
./compile.sh
if test -f "terrains.img"; then
  echo "Using existing terrains.img file."
else
  make spiflash
fi
iceprog -o 1M terrains.img
make icebreaker

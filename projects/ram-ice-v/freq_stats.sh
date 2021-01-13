#!/bin/bash

for i in {1..20}
do
  make ulx3s tool=shell -f Makefile.bram > foo.txt 2>&1
  FREQ="`grep "Max frequency for clock" foo.txt | tail -4`"
  SIZE="`grep "Total LUT4s" foo.txt | tail -1`"
  echo -e "$i -------------------\n"
  echo -e "$FREQ"
  echo -e "$SIZE"
  echo -e "$i -------------------\n" >> stats.txt
  echo -e "$FREQ" >> stats.txt
  echo -e "$SIZE" >> stats.txt
  cp BUILD_ulx3s/build.bit BUILD_ulx3s/$i_build.bit
done

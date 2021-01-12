#!/bin/bash

for i in {1..20}
do
  make ulx3s tool=shell -f Makefile.bench > foo.txt 2>&1
  FREQ="`grep "Max frequency for clock" foo.txt | tail -1`"
  SIZE="`grep "Total LUT4s" foo.txt | tail -1`"
  echo -e "-------------------\n"
  echo -e "$FREQ"
  echo -e "$SIZE"
  echo -e "-------------------\n" >> stats.txt
  echo -e "$FREQ" >> stats.txt
  echo -e "$SIZE" >> stats.txt
done

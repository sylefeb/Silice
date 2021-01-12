#!/bin/bash

for i in {1..20}
do
  make ulx3s tool=shell -f Makefile.bench > foo.txt 2>&1
  VAR="`grep "Max frequency for clock" foo.txt | tail -1`"
  echo -e "$VAR"
  echo -e "-------------------\n" >> stats.txt
  echo -e "$VAR" >> stats.txt
done

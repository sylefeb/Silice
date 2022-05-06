#!/bin/bash
for i in {4..160}
do
  echo "\$\$z_num_step = $i" > param.si
  ./simul.sh
  n=$(printf "%03d" $i)
  cp BUILD_verilator/vgaout_0006.tga SCRATCH/$n.tga
done

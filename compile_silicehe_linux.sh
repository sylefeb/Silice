#!/bin/bash

git submodule init
git submodule update

mkdir BUILD
cd BUILD

mkdir build-silicehe
cd build-silicehe

cmake -DCMAKE_BUILD_TYPE=Release -G "Unix Makefiles" ../../tools/silice_hardware_emulator
make install

cd ..

cd ..

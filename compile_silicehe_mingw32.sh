#!/bin/bash

git submodule init
git submodule update

mkdir BUILD
cd BUILD

pacman -S --noconfirm --needed unzip wget perl cmake gcc g++ make

mkdir build-silicehe
cd build-silicehe

cmake -DCMAKE_BUILD_TYPE=Release -G "MinGW Makefiles" ../../tools/silice_hardware_emulator
mingw32-make install

cd ..

cd ..

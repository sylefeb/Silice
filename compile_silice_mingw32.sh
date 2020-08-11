#!/bin/bash

git submodule init
git submodule update

mkdir BUILD
cd BUILD

pacman -S --noconfirm --needed unzip wget perl cmake gcc make

wget -c https://download.java.net/java/GA/jdk14.0.1/664493ef4a6946b186ff29eb326336a2/7/GPL/openjdk-14.0.1_windows-x64_bin.zip
unzip -o openjdk-14.0.1_windows-x64_bin.zip

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/jdk-14.0.1/bin/

mkdir build-silice
cd build-silice

/mingw32/bin/cmake -DCMAKE_BUILD_TYPE=Release -G "MinGW Makefiles" ../..
mingw32-make -j16 install

cd ..

cd ..

#!/bin/bash

git submodule init
git submodule update

mkdir BUILD
cd BUILD

echo -e "\nInstalling compilation packages for building Silice\n"
pacman -S --noconfirm --needed unzip wget perl ${MINGW_PACKAGE_PREFIX}-cmake ${MINGW_PACKAGE_PREFIX}-gcc ${MINGW_PACKAGE_PREFIX}-make ${MINGW_PACKAGE_PREFIX}-python3 ${MINGW_PACKAGE_PREFIX}-python-pip ${MINGW_PACKAGE_PREFIX}-freeglut

echo -e "\nInstalling python packages for building designs\n"
pip install termcolor
pip install edalize

echo -e "\nDownloading JDK (for building only, not required afterwards)\n"
wget -c https://download.java.net/java/GA/jdk14.0.1/664493ef4a6946b186ff29eb326336a2/7/GPL/openjdk-14.0.1_windows-x64_bin.zip
unzip -o openjdk-14.0.1_windows-x64_bin.zip

# update PATH
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/jdk-14.0.1/bin/

# build
mkdir build-silice
cd build-silice

/mingw64/bin/cmake -DCMAKE_BUILD_TYPE=Release -G "MinGW Makefiles" ../..
mingw32-make -j16 install

cd ..

cd ..

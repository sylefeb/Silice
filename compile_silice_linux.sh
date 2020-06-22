#!/bin/bash

sudo apt install default-jre
sudo apt install default-jdk
sudo apt install iverilog
sudo apt install verilator
sudo apt install fpga-icestorm
sudo apt install arachne-pnr
sudo apt install yosys
sudo apt install gtkwave
sudo apt install git
sudo apt install gcc
sudo apt install g++
sudo apt install make
sudo apt install cmake
sudo apt install pkg-config
sudo apt install uuid
sudo apt install uuid-dev

git submodule init
git submodule update

mkdir BUILD
cd BUILD

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/jdk-14.0.1/bin/

mkdir build-silice
cd build-silice

cmake -DCMAKE_BUILD_TYPE=Release -G "Unix Makefiles" ../..
make -j16 install

cd ..

cd ..

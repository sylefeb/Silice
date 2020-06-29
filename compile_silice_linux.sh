#!/bin/bash

sudo apt install default-jre
sudo apt install default-jdk

if ! type "iverilog" > /dev/null; then
sudo apt install iverilog
else
echo "iverilog already installed, skipping"
fi

if ! type "iceprog" > /dev/null; then
sudo apt install fpga-icestorm
else
echo "fpga-icestorm already installed, skipping"
fi

if ! type "arachne-pnr" > /dev/null; then
sudo apt install arachne-pnr
else
echo "arachne-pnr already installed, skipping"
fi

if ! type "yosys" > /dev/null; then
sudo apt install yosys
else
echo "yosys already installed, skipping"
fi

if ! type "verilator" > /dev/null; then
sudo apt install verilator
else
echo "verilator already installed, skipping"
fi

if ! type "gtkwave" > /dev/null; then
sudo apt install gtkwave
else
echo "gtkwave already installed, skipping"
fi

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

#!/bin/bash

if ! type "javac" > /dev/null; then
  echo "Silice compilation requires javac (typically in package default-jdk or jdk-openjdk)"
  exit
fi

git submodule init
git submodule update

mkdir BUILD
cd BUILD

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/jdk-14.0.1/bin/

mkdir build-silice
cd build-silice

cmake -DCMAKE_BUILD_TYPE=Release -G "Unix Makefiles" ../..
make -j$(nproc) install

cd ..

cd ..

echo -e "\nInstalling python packages for building designs\n"
pip install termcolor
pip install edalize

echo " "
echo " "
echo "=================================="
echo "Please compile and install:"
echo "- yosys"
echo "- trellis, icestorm, nextpnr"
echo "- verilator"
echo "- icarus verilog"
echo " "
echo "See also GetStarted_Linux.md"
echo "=================================="

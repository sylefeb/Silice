#!/bin/bash

if ! type "javac" > /dev/null; then
  echo "Silice compilation requires javac (typically in package default-jdk or jdk-openjdk)"
  exit
fi

git submodule init
git submodule update
rm -f bin/silice || true

mkdir BUILD
cd BUILD

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/jdk-14.0.1/bin/

mkdir build-silice
cd build-silice

cmake -DCMAKE_BUILD_TYPE=Release -G "Unix Makefiles" ../..
make -j$(nproc)
sudo make -j$(nproc) install

cd ..
cd ..

echo " "
echo " "
echo "======================================"
echo "   Please read GetStarted_Linux.md"
echo "======================================"

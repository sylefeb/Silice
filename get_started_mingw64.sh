#!/bin/bash
echo "--------------------------------------------------------------------"
echo "This script installs all necessary packages and compiles Silice"
echo "Please refer to the script source code to see the list of packages"
echo "--------------------------------------------------------------------"

read -p "Please type 'y' to go ahead, any other key to exit: " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
	echo
	echo "Exiting."
	exit
fi

pacman -S --noconfirm --needed unzip
pacman -S --noconfirm --needed wget
pacman -S --noconfirm --needed make
pacman -S --noconfirm --needed python3
pacman -S --noconfirm --needed python-pip
pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-riscv64-unknown-elf-toolchain
pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-iverilog
pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-gtkwave
pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-verilator
pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-openFPGALoader
# pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-nextpnr
# pacman -S --noconfirm --needed  ${MINGW_PACKAGE_PREFIX}-icestorm
# pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-prjtrellis

wget -c https://github.com/sylefeb/fpga-binutils/releases/download/v20220607/fpga-binutils-64.zip

unzip -o fpga-binutils-64.zip -d tools/fpga-binutils/

rm fpga-binutils-64.zip

./compile_silice_mingw64.sh

DIR=`pwd`
echo 'export PATH=$PATH:'$DIR/bin':'$DIR/tools/fpga-binutils/mingw64/bin >> ~/.bashrc

echo ""
echo "--------------------------------------------------------------------"
echo "Please start a new shell before using Silice (PATH has been changed)"
echo "--------------------------------------------------------------------"

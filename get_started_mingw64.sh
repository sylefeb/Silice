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

# -------------- install packages ----------------------------
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
pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-dfu-util
#pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-icestorm
#pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-prjtrellis
pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-boost
# pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-nextpnr
# pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-yosys
pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-glfw

# -------------- get pre-compile binaries (no longer used) ---
# wget -c https://github.com/sylefeb/fpga-binutils/releases/download/v20230510/fpga-binutils-64.zip
# unzip -o fpga-binutils-64.zip -d tools/fpga-binutils/
# rm fpga-binutils-64.zip

# -------------- retrieve oss-cad-suite package --------------
OSS_CAD_MONTH=11
OSS_CAD_DAY=29
OSS_CAD_YEAR=2023

rm -rf tools/fpga-binutils/
rm -rf tools/oss-cad-suite/
wget -c https://github.com/YosysHQ/oss-cad-suite-build/releases/download/$OSS_CAD_YEAR-$OSS_CAD_MONTH-$OSS_CAD_DAY/oss-cad-suite-windows-x64-$OSS_CAD_YEAR$OSS_CAD_MONTH$OSS_CAD_DAY.exe
cd tools ; ../oss-cad-suite-windows-x64-$OSS_CAD_YEAR$OSS_CAD_MONTH$OSS_CAD_DAY.exe ; cd -

# -------------- compile Silice -----------------------------
./compile_silice_mingw64.sh

# -------------- add path to .bashrc ------------------------
DIR=`pwd`
echo 'export PATH=$PATH:'$DIR/bin >> ~/.bashrc
echo 'source '$DIR'/tools/oss-cad-suite-env.sh' >> ~/.bashrc

echo ""
echo "--------------------------------------------------------------------"
echo "Please start a new shell before using Silice (PATH has been changed)"
echo "--------------------------------------------------------------------"

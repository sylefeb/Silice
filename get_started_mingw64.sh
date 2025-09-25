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
# pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-iverilog
# pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-gtkwave
# pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-verilator
# pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-openFPGALoader
pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-dfu-util
pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-boost
pacman -S --noconfirm --needed ${MINGW_PACKAGE_PREFIX}-glfw

# -------------- retrieve oss-cad-suite package --------------
OSS_CAD_MONTH=02
OSS_CAD_DAY=27
OSS_CAD_YEAR=2025
OSS_PACKAGE=oss-cad-suite-windows-x64-$OSS_CAD_YEAR$OSS_CAD_MONTH$OSS_CAD_DAY.exe

rm -rf tools/fpga-binutils/
rm -rf tools/oss-cad-suite/
rm -rf /usr/local/share/silice
wget -c https://github.com/YosysHQ/oss-cad-suite-build/releases/download/$OSS_CAD_YEAR-$OSS_CAD_MONTH-$OSS_CAD_DAY/$OSS_PACKAGE
mkdir -p /usr/local/share/silice
mv $OSS_PACKAGE /usr/local/share/silice/
cp tools/oss-cad-suite-env.sh /usr/local/share/silice/
cd /usr/local/share/silice ; ./$OSS_PACKAGE ; rm ./$OSS_PACKAGE ; cd -

# the python version shipped with oss-cad-tools creates problems
rm -f /usr/local/share/silice/oss-cad-suite/lib/python3.exe
rm -f /usr/local/share/silice/oss-cad-suite/lib/pip3.exe
# the perl redirection of verilator is broken (and not necessary)
rm -f /usr/local/share/silice/oss-cad-suite/share/verilator/bin/verilator

# -------------- compile Silice -----------------------------
./compile_silice_mingw64.sh

# -------------- add path to .bashrc ------------------------
DIR=`pwd`
echo 'source /usr/local/share/silice/oss-cad-suite-env.sh' >> ~/.bashrc

echo ""
echo "--------------------------------------------------------------------"
echo "Please start a new shell before using Silice (PATH has been changed)"
echo "--------------------------------------------------------------------"

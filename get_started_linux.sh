#!/bin/bash
echo "--------------------------------------------------------------------"
echo "This script installs necessary packages, compiles and install Silice"
echo "Please refer to the script source code to see the list of packages"
echo "--------------------------------------------------------------------"
echo "     >>>> it will request sudo access to install packages <<<<"
echo "--------------------------------------------------------------------"

read -p "Please type 'y' to go ahead, any other key to exit: " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
	echo
	echo "Exiting."
	exit
fi

# -------------- install packages ----------------------------
# attempt to guess
source /etc/os-release
if [ "$ID" == "arch"  ]; then
  sudo ./install_dependencies_archlinux.sh
else
	if [ "$ID" == "fedora"  ]; then
		sudo ./install_dependencies_fedora.sh
	else
		if [ "$ID" == "debian"  ] || [ "$ID_LIKE" == "debian"  ]; then
			sudo ./install_dependencies_debian_like.sh
		else
			echo "Cannot determine Linux distrib to install dependencies\n(if this fails please run the install_dependencies script that matches your distrib)."			
		fi
	fi
fi

# -------------- retrieve oss-cad-suite package --------------
OSS_CAD_MONTH=11
OSS_CAD_DAY=29
OSS_CAD_YEAR=2023

rm -rf tools/fpga-binutils/
rm -rf tools/oss-cad-suite/
wget -c https://github.com/YosysHQ/oss-cad-suite-build/releases/download/$OSS_CAD_YEAR-$OSS_CAD_MONTH-$OSS_CAD_DAY/oss-cad-suite-linux-x64-$OSS_CAD_YEAR$OSS_CAD_MONTH$OSS_CAD_DAY.tgz
cd tools ; tar xvfz ../oss-cad-suite-linux-x64-$OSS_CAD_YEAR$OSS_CAD_MONTH$OSS_CAD_DAY.tgz ; cd -

# -------------- compile Silice -----------------------------
./compile_silice_linux.sh

# -------------- add path to .bashrc ------------------------
DIR=`pwd`
echo 'export PATH=$PATH:'$DIR/bin >> ~/.bashrc
echo 'source '$DIR'/tools/oss-cad-suite-env.sh' >> ~/.bashrc

echo ""
echo "--------------------------------------------------------------------"
echo "Please start a new shell before using Silice (PATH has been changed)"
echo "--------------------------------------------------------------------"

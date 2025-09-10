#!/bin/bash
echo "--------------------------------------------------------------------"
echo "This script installs all necessary python packages"
echo "Requirements: python and pip"
echo ""
echo "You may run into the error externally-managed-environment, in which"
echo "case you can create a venv for local package installation."
echo " https://docs.python.org/3/library/venv.html "
# e.g. https://stackoverflow.com/questions/75602063/pip-install-r-requirements-txt-is-failing-this-environment-is-externally-mana
echo ""
echo "Please refer to the script source code to see the list of packages"
echo "--------------------------------------------------------------------"

read -p "Please type 'y' to go ahead, any other key to exit: " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
	echo
	echo "Exiting."
	exit
fi

pip install yowasp-yosys
pip install yowasp-nextpnr-ice40
pip install yowasp-nextpnr-ecp5
pip install yowasp-silice
pip install edalize

# Getting started with Silice on Windows

## Install and compile

Silice runs smoothly under Windows using [MSYS2 / MinGW64](https://www.msys2.org/). MSYS2 is great to
use Linux-style tools under Windows, and installs a self-contained environment easy to later uninstall.

Please download and install MSYS2 (msys2-x86_64) from https://www.msys2.org/
Be sure to follow the instructions on the download page to update your MSYS2 install to latest.

From there, open a MinGW64 prompt, launching `c:\msys64\mingw64.exe` (assuming MSYS2 is 
installed in its default location). Be sure to use MinGW**64**, *not* 32, *nor* a MSYS prompt.

The prompt should look like this (note the MinGW64 label in purple):
<p align="center">
  <img width="512" src="docs/figures/mingw64_prompt.png">
</p>

Then, from the prompt, enter the Silice directory and type: `./get_started_mingw64.sh`.

> **Note:** The script adds Silice and the FPGA toolchain to PATH in` ~/.bashrc`. Open a new MinGW64 prompt to start using Silice.

> **Note:** This automatically downloads a pre-compiled FPGA + RiscV toolchain from https://github.com/sylefeb/fpga-binutils/ (~290MB) as well as installs required MinGW64 packages. For details please refer to the [script source code](get_started_mingw64.sh).

## Drivers

### USB and ice40 (IceStick / IceBreaker) under Windows
To program with *iceprog* under Windows, you may have to use the [Zadig USB tool](https://zadig.akeo.ie/) to swap the driver. To do this, connect the board, launch Zadig, select the board from the drop-down menu (interface 0), and change the driver for 'libusbK' (select it on the right side). Click replace, wait, disconnect the board, put it back, should be working now. I've done this several times without issues. If it still does not work, verify the USB port is not a hub (some USB ports on computer fronts are) and try again from a native USB port on your motherboard.

### USB and ULX3S under Windows
To program the ECP5 with *fujprog* make sure to install the [FTDI CDM drivers](https://www.ftdichip.com/Drivers/D2XX.htm) (available as a setup exe, see right most column under "comments").

## Testing

Time to [run a few tests](GetStarted.md#testing) and [start having fun!](projects/README.md)

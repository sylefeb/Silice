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
  <img width="512" src="learn-silice/figures/mingw64_prompt.png">
</p>

Then, from the prompt, enter the Silice directory and type: `./get_started_mingw64.sh`.

> **Note:** The script downloads necessary MinGW packages, compiles and installs Silice using standard paths (`/usr/local/bin` and `/usr/local/shared/silice`) as well as downloads and sets up the [oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build) FPGA toolchain, adding a line in ` ~/.bashrc`. Open a new MinGW64 prompt to start using Silice.
For details please refer to the [script source code](get_started_mingw64.sh).

## Drivers

### USB programming (IceStick / IceBreaker / ULX3S) under Windows
To program with *iceprog* and *openFPGAloader* under Windows, you may have to use the [Zadig USB tool](https://zadig.akeo.ie/) to swap the driver. To do this, connect the board, launch Zadig, select the board from the drop-down menu (interface 0), and change the driver for 'WinUSB' (select it on the right side). Click replace, wait, disconnect the board, put it back, should be working now. I've done this several times without issues. If it still does not work, verify the USB port is not a hub (some USB ports on computer fronts are) and try again from a native USB port on your motherboard.

## Testing

Time to [run a few tests](GetStarted.md#testing) and [start having fun!](projects/README.md)

# Getting started with Silice on Windows

## Compiling Silice

Silice runs smoothly under Windows using [MSYS2 / MinGW64](https://www.msys2.org/). MSYS2 is great to
use Linux-style tools under Windows, and installs a self-contained environment easy to later uninstall.

Please download and install MSYS2 (msys2-x86_64) from https://www.msys2.org/
Be sure to follow the instructions on the download page to update your MSYS2 install to latest.
From there, to use Silice open a MinGW64 prompt, launching `c:\msys64\mingw64.exe` (assuming MSYS2 is 
installed in its default location). Be sure to use MinGW**64**, *not* 32.

The first step is to compile Silice from source. 

- Install the compiler tools from the MinGW64 shell: `pacman -S gcc make cmake`

- Open a MinGW64 prompt, enter the Silice directory and type: `./compile_silice_mingw64.sh`

## Getting the toolchain

Using Silice with your FPGA requires many other tools. I have prepared a binary package for MinGW64 with the full OpenSource toolchain pre-compiled, 
so you can easily get started! 

- Download fpga-binutils from https://github.com/sylefeb/fpga-binutils/releases

- Uncompress the archive *Silice/tools/fpga-binutils/*

- After this step you should see this new directory: *Silice/tools/fpga-binutils/mingw64/* (with subdirectories: bin, ...)

## Verilator framework

To run simulations with Verilator (**highly recommended**), including SDRAM and VGA output simulations, we have to compile the Silice Verilator framework.

- Start a MinGW64 shell from (assuming default path) c:\msys64\mingw64.exe (64 bits)

- Install the compiler tools from the MinGW64 shell: `pacman -S gcc make cmake perl zlib zlib-devel`

Now we will compile the silice framework for verilator

- Go into the silice folder and type `./compile_verilator_framework_mingw64.sh`

(installs new files in Silice/frameworks/verilator/)

- We are ready to test!

## Testing

Time to [run a few tests](GetStarted.md#testing).

# Getting started with Silice

Here are the instructions to setup Silice. Once done, head out to [writing your first design](FirstDesign.md) or try our [example projects](projects/README.md).

## Linux

Should be as simple as:
```
git clone --recurse-submodules https://github.com/sylefeb/Silice.git
cd Silice
./compile_silice_linux.sh
```

Done! This compiled and installed the Silice executable in silice/bin/

**Note:** The script will attempt to install the following dependencies using apt ; you may have to adapt package names and package manager to your Linux distribution, and/or edit the script to remove any dependency you do not wish to install: 
```
default-jre default-jdk iverilog verilator fpga-icestorm arachne-pnr 
yosys gtkwave git gcc g++ make cmake pkg-config uuid uuid-dev
```

(the Java jre/jdk is only used during compilation)

**Note:** It is highly recommended for all tools to be available from the PATH (yosys, nextpnr, dfu-utils, fujprog, etc.). This is required by the default build system.

## Windows

Silice runs smoothly under Windows using [MSYS2 / MinGW64](https://www.msys2.org/).

Please download and install MSYS2 (msys2-x86_64) from https://www.msys2.org/
Be sure to follow the instructions on the download page to update your MSYS2 install to latest.
From there, to use Silice open a MinGW64 prompt, launching `c:\msys64\mingw64.exe` (assuming MSYS2 installed
in default location). Be sure to use MinGW**64**, *not* 32.

The first step is to compile Silice from source. 

- Install the compiler tools from the MinGW64 shell: `pacman -S gcc make cmake`

- Open a MinGW64 prompt, enter the Silice directory and type: `./compile_silice_mingw64.sh`

### Toolchain

Using Silice with your FPGA requires many other tools. I have prepared a binary package for MinGW64 with the full OpenSource toolchain pre-compiled, 
so you can easily get started! 

- Download fpga-binutils from https://github.com/sylefeb/fpga-binutils/releases

- Uncompress the archive *Silice/tools/fpga-binutils/*

- After this step you should see this new directory: *Silice/tools/fpga-binutils/mingw64/* (with subdirectories: bin, ...)

## Verilator framework

To run simulations with Verilator (**highly recommended**), including SDRAM and VGA output simulations, we have to compile the Silice Verilator framework.

### Windows

- Start a MinGW64 shell from (assuming default path) c:\msys64\mingw64.exe (64 bits)

- Install the compiler tools from the MinGW64 shell: `pacman -S gcc make cmake perl zlib zlib-devel`

Now we will compile the silice framework for verilator

- Go into the silice folder and type `./compile_verilator_framework_mingw64.sh`

(installs new files in Silice/frameworks/verilator/)

- We are ready to test!

### Linux

- Open a command line into the silice folder and type `./compile_verilator_framework_linux.sh`

(installs new files in Silice/frameworks/verilator/)

- We are ready to test!

### Testing

From a shell starting from the silice folder:
```
cd projects
cd vga_demo
make verilator
```

This executes the simulation, which outputs 32 image files (tga format) in the subdirectory *BUILD_verilator*.
Look at them in sequence :-)

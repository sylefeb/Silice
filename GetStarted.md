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

## macOS (WIP)

Install the packages listed in the Linux section above (except gcc,
g++, other builtin packages).

Then:

```
git clone --recurse-submodules https://github.com/sylefeb/Silice.git
cd Silice

mkdir BUILD
cd BUILD
mkdir build-silice
cd build-silice

cmake -DCMAKE_BUILD_TYPE=Release -G "Unix Makefiles" ../..
make -j16 install
```

## Windows

I have prepared binary packages for Windows so you can easily get started!
Download the pre-compiled fpga-binutils from https://github.com/sylefeb/fpga-binutils/releases

There are two versions: 32 bits and 64 bits. I recommend using the 64 bits version, even though you may need
both since a few tools compile to 32 bits only.

Uncompress in Silice/tools/fpga-binutils/

After this step you should see these new directories:
- Silice/tools/fpga-binutils/mingw32/ (with subdirectories: bin, ...)
- Silice/tools/fpga-binutils/mingw64/ (with subdirectories: bin, ...)

## Verilator framework

To use build shell scripts (.sh) and the Verilator simulation framework: (**highly recommended**)

### Windows

- Download and install MSYS2 (msys2-x86_64) from https://www.msys2.org/
  Be sure to follow the instructions on the download page to update your 
  MSYS2 install to latest.

- Start a MinGW shell from (assuming default path) c:\msys64\mingw32.exe (32 bits) or c:\msys64\mingw64.exe (64 bits)

- Install the compiler tools from the MinGW shell:
  pacman -S gcc make cmake perl zlib zlib-devel

Now we will compile the silice framework for verilator

- Go into the silice folder and type (for 32 bits version, use 64 prefix for 64 bits version)
```
./compile_verilator_framework_mingw32.sh
```

(installs new files in Silice/frameworks/verilator/)

- We are ready to test!

### Linux and macOS

- Open a command line into the silice folder and type
```
./compile_verilator_framework_linux.sh
```
or
```
./compile_verilator_framework_macos.sh
```

(installs new files in Silice/frameworks/verilator/)

- We are ready to test!

### Testing

From a shell starting from the silice folder:
```
cd projects
cd build
cd verilator
./verilator_sdram_vga.sh ../../vga_text_buffer/vga_text_buffer.ice
./test_____vga_text_buffer__vga_text_bufferice.exe
```
**IMPORTANT** under Windows, if you compiled for 64 bits, use a MinGW64 shell and the script ```/verilator_sdram_vga_64.sh``` instead.

=> This executes the simulation, which outputs 40 image files (tga format)
Look at them in sequence :-)

*Note:* Under MinGW you can also compile *silice* and *silicehe* using the provided shell scripts in the root silice directory.

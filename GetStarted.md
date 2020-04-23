# Getting started with Silice

## Windows

Download the pre-compiled fpga-binutils from XXX. 

Uncompress in silice/tools/fpga-binutils/mingw32/

After this step you should see three new directories:
- Silice/tools/fpga-binutils/mingw32/bin
- Silice/tools/fpga-binutils/mingw32/include
- Silice/tools/fpga-binutils/mingw32/lib

For use with Verilator:

- Download and install MSYS2 (msys2-x86_64) from https://www.msys2.org/
  Be sure to follow the instructions on the download page to update your 
  MSYS2 install to latest.

- Start a MinGW32 shell from (assuming default path) c:\msys64\mingw32.exe
  (IMPORTANT: the shell has to be a MinGW 32bits shell)

- Install the compiler tools from the MinGW32 shell:
  pacman -S gcc make cmake perl

Now we will compile the silice framework for verilator

- Go into the silice folder and type 
```
./compile_verilator_framework_mingw32.sh
```

(installs new files in Silice/frameworks/verilator/)

- Now we are ready to test!

```
cd projects
cd build
cd verilator
./verilator_sdram_vga.sh ../../vga_text_buffer/vga_text_buffer.ice
./test_____vga_text_buffer__vga_text_bufferice.exe
```

=> This executes the simulation, which output 40 image files (tga format)
Look at them in sequence :-)

## Linux

Install the following dependencies (this was tested on Ubuntu, you may have to adapt package names and package manager to your Linux distribution):
```
sudo apt install default-jre
sudo apt install default-jdk
sudo apt install iverilog
sudo apt install verilator
sudo apt install fpga-icestorm
sudo apt install arachne-pnr
sudo apt install yosys
sudo apt install gtkwave
sudo apt install git
sudo apt install gcc
sudo apt install g++
sudo apt install make
sudo apt install cmake
sudo apt install pkg-config
sudo apt install uuid
sudo apt install uuid-dev
git clone --recurse-submodules https://github.com/sylefeb/Silice.git
cd Silice
mkdir BUILD
cd BUILD
cmake .. -DCMAKE_BUILD_TYPE=Release
make
make install
cd ..
rm -rf BUILD
```

Done! This compiled and install the Silice executable in silice/bin/

(Note: the Java jre/jdk is only used during compilation)


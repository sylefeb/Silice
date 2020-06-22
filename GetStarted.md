# Getting started with Silice

## Windows

I have prepared binary packages for Windows so you can easily get started!
Download the pre-compiled fpga-binutils from https://github.com/sylefeb/fpga-binutils/releases

Uncompress in Silice/tools/fpga-binutils/

After this step you should see three new directories:
- Silice/tools/fpga-binutils/mingw32/bin
- Silice/tools/fpga-binutils/mingw32/include
- Silice/tools/fpga-binutils/mingw32/lib

To use shell scripts (.sh) and the Verilator simulation framework: (**highly recommended**)

- Download and install MSYS2 (msys2-x86_64) from https://www.msys2.org/
  Be sure to follow the instructions on the download page to update your 
  MSYS2 install to latest.

- Start a MinGW32 shell from (assuming default path) c:\msys64\mingw32.exe
  (IMPORTANT: the shell has to be a MinGW 32bits shell)

- Install the compiler tools from the MinGW32 shell:
  pacman -S gcc make cmake perl zlib zlib-devel

Now we will compile the silice framework for verilator

- Go into the silice folder and type 
```
./compile_verilator_framework_mingw32.sh
```

(installs new files in Silice/frameworks/verilator/)

- We are ready to test!

```
cd projects
cd build
cd verilator
./verilator_sdram_vga.sh ../../vga_text_buffer/vga_text_buffer.ice
./test_____vga_text_buffer__vga_text_bufferice.exe
```

=> This executes the simulation, which output 40 image files (tga format)
Look at them in sequence :-)

*Note:* Under MinGW you can also compile *silice* and *silicehe* using the provided shell scripts in the root directory.

## Linux

Should be as easy as
```
git clone --recurse-submodules https://github.com/sylefeb/Silice.git
cd Silice
./compile_silice_linux.sh
```

Done! This compiled and install the Silice executable in silice/bin/

*Note:* The script will attempt to install the following dependencies using apt ; you may have to adapt package names and package manager to your Linux distribution: 
```default-jre default-jdk iverilog verilator fpga-icestorm arachne-pnr yosys gtkwave git gcc g++ make cmake pkg-config uuid uuid-dev
```

(the Java jre/jdk is only used during compilation)

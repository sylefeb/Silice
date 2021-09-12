# Getting started with Silice on Linux

## Compiling Silice

First, some dependencies are required. To install all of them you may run the script `install_dependencies_linux.sh` that uses `apt`, or inspect the script content and manually add the missing packages. Note that the Java jre/jdk are only required for compilation.

Compiling Silice should then be as simple as:
```shell
git clone --recurse-submodules https://github.com/sylefeb/Silice.git
cd Silice
./compile_silice_linux.sh
```

Done! This compiled and installed the Silice executable in `Silice/bin/`.

**Note:** It is highly recommended for all tools to be available from the PATH (Silice/bin, yosys, nextpnr, dfu-utils, fujprog, etc.). This is required by the default build system.

## Getting the toolchain

Using Silice with your FPGA requires many other tools: yosys, icestorm, trellis, nextpnr, verilator, icarus verilog (*iverilog*), gtkwave, fujprog, dfu-utils.

**Note:** It is highly recommended for all tools to be available from the PATH. This is required by the default build system.

The most critical are yosys, icestorm, trellis, nextpnr. For these ones, please do not use any package that
may come with your system. These are likely outdated and won't understand the latest features. Verilator also often needs to be updated.

There are two options:

### Compile from source (recommended)

Yosys, icestorm, trellis, nextpnr, verilator are not difficult to compile and install, and have detailed instructions on their git pages:
- [Yosys](https://github.com/YosysHQ/yosys)
- [Project trellis](https://github.com/YosysHQ/prjtrellis)
- [Project icestorm](https://github.com/YosysHQ/icestorm)
- [NextPNR](https://github.com/YosysHQ/nextpnr)
- [Verilator](https://github.com/verilator/verilator)

Note that trellis and icestorm have to be compiled and installed before nextpnr (please refer to the NextPNR setup instructions). 

These tools take a bit of time to compile, but it is worth doing as they constantly improve.

> **Note** You might want to apply my [ice40 DSP patch](https://github.com/sylefeb/fpga-binutils/blob/master/patches/yosys_patch_ice40_dsp.diff) on Yosys before compiling.

### Use compiled binaries

Checkout the [fpga-toolchain project](https://github.com/open-tool-forge/fpga-toolchain) as they provide nightly builds of many tools for multiple platforms. 

## Testing

Time to [run a few tests](GetStarted.md#testing).

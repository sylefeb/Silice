# Getting started with Silice on Linux

## Compiling Silice

Install the following packages: `default-jre default-jdk git uuid uuid-dev`, then:

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

(the Java jre/jdk is only used during compilation)

## Getting the toolchain

Using Silice with your FPGA requires many other tools: yosys, icestorm, trellis, nextpnr, verilator, icarus verilog (*iverilog*), gtkwave, fujprog, dfu-utils.

**Note:** It is highly recommended for all tools to be available from the PATH. This is required by the default build system.

The most critical are yosys, icestorm, trellis, nextpnr. For these ones, please do not use any package that
may come with your system. These are likely outdated and won't understand the latest features. Verilator also often needs to be updated.

There are two options:

### Compile from source

Yosys, icestorm, trellis, nextpnr, verilator are not difficult to compile and install, and have detailed instructions on their git pages:
- [Yosys](https://github.com/YosysHQ/yosys)
- [Project trellis](https://github.com/YosysHQ/prjtrellis)
- [Project icestorm](https://github.com/YosysHQ/icestorm)
- [NextPNR](https://github.com/YosysHQ/nextpnr)
- [Verilator](https://github.com/verilator/verilator)

Note that trellis and icestorm have to be compiled and installed before nextpnr (please refer to the NextPNR setup instructions). 

These tools take a bit of time to compile, but is worth doing as they constantly improve.

### Use compiled binaries

Checkout the [fpga-toolchain project](https://github.com/open-tool-forge/fpga-toolchain) as they provide nightly builds of many tools for multiple platforms. 

## Verilator framework

To run simulations with Verilator (**highly recommended**), including SDRAM and VGA output simulations, we have to compile the Silice Verilator framework.

- Open a command line into the silice folder and type
```
./compile_verilator_framework_macos.sh
```

(installs new files in Silice/frameworks/verilator/)

## Testing

Time to [run a few tests](projects/GetStarted.md#testing).


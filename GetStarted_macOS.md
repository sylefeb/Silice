# Getting started with Silice on MacOS

## Prerequisite
You need to have homebrew installed
Make sure to have python3 and the package termcolor installed

## Compiling Silice

Install the following packages: `default-jre default-jdk git uuid ossp-uuid`, then:

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

### Optional : 
add the following line to your .zprofile file : 

```
export PATH="/path/to/Silice/bin:$PATH
```


## Getting the toolchain

Using Silice with your FPGA requires many other tools: yosys, icestorm, trellis, nextpnr, verilator, icarus verilog (*iverilog*), gtkwave, fujprog, dfu-utils.

**Note:** It is highly recommended for all tools to be available from the PATH. This is required by the default build system.

The most critical are yosys, icestorm, trellis, nextpnr. For these ones, please do not use any package that
may come with your system. These are likely outdated and won't understand the latest features. Verilator also often needs to be updated.

There are three options:

### Compile from source

Yosys, icestorm, trellis, nextpnr, verilator are not difficult to compile and install, and have detailed instructions on their git pages:
- [Yosys](https://github.com/YosysHQ/yosys)
- [Project trellis](https://github.com/YosysHQ/prjtrellis)
- [Project icestorm](https://github.com/YosysHQ/icestorm)
- [NextPNR](https://github.com/YosysHQ/nextpnr)
- [Verilator](https://github.com/verilator/verilator)


Note that trellis and icestorm have to be compiled and installed before nextpnr (please refer to the NextPNR setup instructions). 

These tools take a bit of time to compile, but is worth doing as they constantly improve.

### Use homebrew

To install those package, type following commands : 

```
brew tap ktemkin/oss-fpga
brew install --HEAD icestorm yosys nextpnr-ice40 project-trellis nextpnr-trellis verilator icarus-verilog 
```

To install gtkwave checkout this git [gtkwave](https://ughe.github.io/2018/11/06/gtkwave-osx) for detailled instruction

### Use compiled binaries

Checkout the [fpga-toolchain project](https://github.com/open-tool-forge/fpga-toolchain) as they provide nightly builds of many tools for multiple platforms. 

## Testing

Time to [run a few tests](GetStarted.md#testing).

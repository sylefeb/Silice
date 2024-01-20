# Getting started with Silice on Linux

## Compiling Silice

Hopefully this will be as simple as running `./get_started_linux.sh`
Beware that this script is installing dependencies and will request sudo access. If that is not ok, please open the script and see what it wants to install.

Dependencies are installed by the scripts `install_dependencies_*.sh`. The `get_started_linux.sh` script attempts to detect your distrib to call the corresponding dependencies installation script, but if that fails you may have to manually install the dependencies. In such a case, please refer to the script's contents to see what's needed. Note that the Java jre/jdk are only required for compilation.

The `get_started_linux.sh` script will install all dependencies, including pre-compiled binaries for the FPGA toolchain (from [oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build)).
It will then compile and install Silice using standard paths (`/usr/local/bin` and `/usr/local/shared/silice`).

## Testing

Time to [run a few tests](GetStarted.md#testing).

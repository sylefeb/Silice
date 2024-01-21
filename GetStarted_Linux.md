# Getting started with Silice on Linux

## Compiling Silice

Hopefully this will be as simple as running `./get_started_linux.sh`
Beware that this script is installing dependencies and will request sudo access.
If that is not ok, please open the script and see what it wants to install.
The script also installs Silice on the system, using standard paths (`/usr/local/bin` and `/usr/local/shared/silice`).
Finally, the script appends paths to `.bashrc`.

## Notes on dependencies

The `get_started_linux.sh` script calls the scripts `install_dependencies_*.sh` to install dependencies. It attempts to detect your distrib to call the corresponding dependencies installation script, but if that fails you may have to manually install the dependencies. In such a case, please refer to the script's contents to see what is needed. Note that the Java jre/jdk are only required for compilation.

The script also downloads and sets up pre-compiled binaries for the FPGA toolchain (from [oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build)). These are placed in the `Silice/tools/`, and environment variables are set by adding a line to the user's `.bashrc`

## Testing after installation

Time to [run a few tests](GetStarted.md#testing) and [start having fun!](projects/README.md)

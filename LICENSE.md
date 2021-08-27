# Silice license information

Silice itself (the compiler and its documentation) is licensed under the GPL v3 
Open Source license, see [full text here](LICENSE_GPLv3). 
A few exceptions apply when external code has been included, generally under 
more permissive license. Each source file contains its license info (if that is 
missing, please let me know and I'll include it asap).

[Example projects](projects/README.md) are licensed under the MIT license, 
see [full text here](LICENSE_MIT). Each example source file contains its license 
info.

The Silice compiler generates Verilog code, that can then be fed into an FPGA
toolchain. Beyond your own compiled code, this Verilog code embeds some 
Silice specific glue code. This glue code is entirely under the [MIT license](LICENSE_MIT), 
so that you can freely use Verilog code compiled with Silice.

Silice depends on a number of external libraries. These are included in separate
directories with their own license files.

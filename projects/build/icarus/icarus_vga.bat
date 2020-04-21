..\..\..\bin\silice -f ..\..\..\frameworks\icarus_vga.v %1 -o build.v
iverilog -o build build.v
vvp build -fst

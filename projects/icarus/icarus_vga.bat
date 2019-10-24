..\..\bin\silice -f ..\..\frameworks\icarus_vga.v %1 -o testicarus.v
iverilog -pfileline=1 -Wall -Winfloop -o testicarus testicarus.v
REM iverilog -o testicarus testicarus.v
vvp testicarus -fst

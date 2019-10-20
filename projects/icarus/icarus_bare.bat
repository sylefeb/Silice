..\..\bin\silice -f ..\..\frameworks\icarus_bare.v %1 -o testicarus.v
iverilog -o testicarus testicarus.v
vvp testicarus -fst

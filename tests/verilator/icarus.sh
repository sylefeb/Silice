../../bin/silice -f ../../frameworks/icarus.v unoptflat.ice -o testicarus.v ; iverilog -pfileline=1 -o testicarus testicarus.v ; vvp testicarus

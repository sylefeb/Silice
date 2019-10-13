../../bin/silice -f ../../frameworks/icarus.v $1 -o testicarus.v ; iverilog -o testicarus testicarus.v ; vvp testicarus

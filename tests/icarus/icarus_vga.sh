../../bin/silice -f ../../frameworks/icarus_vga.v $1 -o testicarus.v ; iverilog -o testicarus testicarus.v ; vvp testicarus

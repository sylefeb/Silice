# inform quartus that the clk port brings a 50MHz clock into our design so
	# that timing closure on our design can be analyzed

create_clock -name clk -period "50MHz" [get_ports clk]
derive_pll_clocks -create_base_clocks
derive_clock_uncertainty

# inform quartus that the LED output port has no critical timing requirements
	# its a single output port driving an LED, there are no timing relationships
	# that are critical for this

set_false_path -from * -to [get_ports led[0]]
set_false_path -from * -to [get_ports led[1]]
set_false_path -from * -to [get_ports led[2]]
set_false_path -from * -to [get_ports led[3]]
set_false_path -from * -to [get_ports led[4]]
set_false_path -from * -to [get_ports led[5]]
set_false_path -from * -to [get_ports led[6]]
set_false_path -from * -to [get_ports led[7]]

# inform quartus that the clk port brings a 50MHz clock into our design so
	# that timing closure on our design can be analyzed

create_clock -name clk -period "50MHz" [get_ports clk]

# inform quartus that the LED output port has no critical timing requirements
	# its a single output port driving an LED, there are no timing relationships
	# that are critical for this

set_false_path -from * -to [get_ports LED0]
set_false_path -from * -to [get_ports LED1]
set_false_path -from * -to [get_ports LED2]
set_false_path -from * -to [get_ports LED3]
set_false_path -from * -to [get_ports LED4]
set_false_path -from * -to [get_ports LED5]
set_false_path -from * -to [get_ports LED6]
set_false_path -from * -to [get_ports LED7]

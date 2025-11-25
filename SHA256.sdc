create_clock -name clk -period 20.0 [get_ports clk]
set_false_path -from [get_ports reset_n]

derive_clock_uncertainty

# Input delay 
set_input_delay -clock clk 0 [remove_from_collection [all_inputs] [get_ports clk]]

# Output delay
set_output_delay 0 -clock clk [all_outputs]

# 1. 90MhHz clock
create_clock -name clk -period 11.1 [get_ports clk]
derive_clock_uncertainty

# 2. Reset (Asynchronous)
set_false_path -from [get_ports reset_n]
set_false_path -to   [get_ports reset_n]

# 3. Gom nhóm Data Inputs/Outputs
set data_inputs [remove_from_collection [all_inputs] [get_ports {clk reset_n}]]
set data_outputs [all_outputs]
set_input_delay -max 0.0 -clock clk $data_inputs 
set_input_delay -min 0.0 -clock clk $data_inputs 

set_output_delay -max 0.0 -clock clk $data_outputs 
set_output_delay -min 0.0 -clock clk $data_outputs
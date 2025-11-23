# Khai báo clock chính
create_clock -name clk -period 20.0 [get_ports clk]
set_false_path -from [get_ports reset_n]

# Input delay (optional)
set_input_delay 0 -clock clk [all_inputs]

# Output delay (optional)
set_output_delay 0 -clock clk [all_outputs]

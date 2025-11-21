transcript on
if {[file exists gate_work]} {
	vdel -lib gate_work -all
}
vlib gate_work
vmap work gate_work

vcom -93 -work work {SHA256.vho}

vlog -vlog01compat -work work +incdir+D:/DOC/quartus {D:/DOC/quartus/tb_sha256.v}

vsim -t 1ps +transport_int_delays +transport_path_delays -sdftyp /NA=SHA256_vhd.sdo -L cycloneii -L gate_work -L work -voptargs="+acc"  tb_sha256

add wave *
view structure
view signals
run -all

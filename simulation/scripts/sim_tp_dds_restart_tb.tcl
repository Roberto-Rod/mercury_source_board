asim -O5 +access +r tp_dds_restart_tb tb

add wave -noreg {/tp_dds_restart_tb/clk}
add wave -noreg {/tp_dds_restart_tb/srst}
add wave -noreg {/tp_dds_restart_tb/ext_blank_n}
add wave -noreg {/tp_dds_restart_tb/tp_async_blank_n}
add wave -noreg {/tp_dds_restart_tb/dds_restart_prep}
add wave -noreg {/tp_dds_restart_tb/dds_restart_exec}

run -all

file mkdir ../sim_logs/tp_dds_restart
file copy -force -- {*}[glob ../active_hdl/mercury_source_board/*.txt] ../sim_logs/tp_dds_restart
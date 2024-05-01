asim -O5 +access +r timing_protocol_tb tb

add wave -noreg {/timing_protocol_tb/reg_clk}
add wave -noreg {/timing_protocol_tb/reg_srst}
add wave -noreg {/timing_protocol_tb/reg_mosi}
add wave -noreg {/timing_protocol_tb/reg_miso}
add wave -noreg {/timing_protocol_tb/tp_async_blank_n}
add wave -noreg {/timing_protocol_tb/tp_sync_en}
add wave -noreg {/timing_protocol_tb/int_pps}
add wave -noreg {/timing_protocol_tb/ext_pps_present}

run -all

file mkdir ../sim_logs/timing_protocol
file copy -force -- {*}[glob ../active_hdl/mercury_source_board/*.txt] ../sim_logs/timing_protocol
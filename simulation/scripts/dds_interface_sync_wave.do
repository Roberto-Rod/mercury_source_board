onerror { resume }
transcript off
add wave -noreg -logic {/dds_interface_tb/i_dut/capture_position_flag}
add wave -noreg -logic {/dds_interface_tb/dds_io_update}
add wave -noreg -logic {/dds_interface_tb/dds_sync_clk}
add wave -noreg -logic {/dds_interface_tb/int_pps}
add wave -noreg -hexadecimal -literal {/dds_interface_tb/i_dut/posn_adjust}
add wave -noreg -hexadecimal -literal {/dds_interface_tb/i_dut/posn_adjust_acc}
add wave -noreg -logic {/dds_interface_tb/i_dut/posn_adjust_valid}
add wave -noreg -logic {/dds_interface_tb/i_dut/posn_inc_dec_n}
add wave -noreg -logic {/dds_interface_tb/i_dut/pps_err_sel}
add wave -noreg -hexadecimal -literal {/dds_interface_tb/i_dut/pps_posn_cnt}
add wave -noreg -hexadecimal -literal {/dds_interface_tb/i_dut/pps_posn_err}
add wave -noreg -hexadecimal -literal {/dds_interface_tb/i_dut/pps_posn_err_hi}
add wave -noreg -hexadecimal -literal {/dds_interface_tb/i_dut/pps_posn_err_lo}
add wave -noreg -hexadecimal -literal {/dds_interface_tb/i_dut/pps_posn_err_lo_abs}
add wave -noreg -hexadecimal -literal {/dds_interface_tb/i_dut/pps_posn_err_hi_abs}
add wave -noreg -logic {/dds_interface_tb/i_dut/pps_posn_err_valid}
cursor "Cursor 1" 1975146302ps  
cursor "Cursor 2" 57012.5ns  -locked
cursor "Cursor 4" 1057012.5ns  
cursor "Cursor 7" 11144831.25ns  
cursor "Cursor 8" 8245831.25ns  
bookmark add 2267.605636us
bookmark add 3236.114874us
transcript on

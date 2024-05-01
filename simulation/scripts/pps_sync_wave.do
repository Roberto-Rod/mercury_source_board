onerror { resume }
transcript off
add wave -noreg -logic {/pps_sync_tb/i_dut/reg_clk_i}
add wave -noreg -logic {/pps_sync_tb/i_dut/reg_srst_i}
add wave -noreg -hexadecimal -literal {/pps_sync_tb/i_dut/reg_mosi_i}
add wave -noreg -hexadecimal -literal {/pps_sync_tb/i_dut/reg_miso_o}
add wave -noreg -logic {/pps_sync_tb/i_dut/ext_pps_i}
add wave -noreg -logic {/pps_sync_tb/i_dut/ext_pps_o}
add wave -noreg -logic {/pps_sync_tb/i_dut/int_pps_o}
add wave -noreg -logic {/pps_sync_tb/i_dut/ext_pps_present_o}
add wave -noreg -hexadecimal -literal {/pps_sync_tb/i_dut/pulse_count}
add wave -noreg -hexadecimal -literal {/pps_sync_tb/i_dut/pps_count}
add wave -noreg -hexadecimal -literal {/pps_sync_tb/i_dut/pps_count_r}
add wave -noreg -hexadecimal -literal {/pps_sync_tb/i_dut/pps_cnt_err}
add wave -noreg -hexadecimal -literal {/pps_sync_tb/i_dut/pps_cnt_err_r}
add wave -noreg -hexadecimal -literal {/pps_sync_tb/i_dut/pps_cnt_err_f}
add wave -noreg -hexadecimal -literal {/pps_sync_tb/i_dut/mult_add_a}
add wave -noreg -hexadecimal -literal {/pps_sync_tb/i_dut/mult_add_b}
add wave -noreg -hexadecimal -literal {/pps_sync_tb/i_dut/mult_add_c}
add wave -noreg -hexadecimal -literal {/pps_sync_tb/i_dut/mult_add_p}
add wave -noreg -logic {/pps_sync_tb/i_dut/pps_count_capture}
add wave -noreg -logic {/pps_sync_tb/i_dut/pps_cnt_err_f_valid}
add wave -noreg -logic {/pps_sync_tb/i_dut/error_limit}
cursor "Cursor 7" 11144831.25ns  
cursor "Cursor 8" 8245831.25ns  
bookmark add 3236.114874us
transcript on

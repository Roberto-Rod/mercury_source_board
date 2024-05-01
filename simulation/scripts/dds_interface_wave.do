onerror { resume }
transcript off
add wave -noreg -logic {/dds_interface_tb/i_dut/dds_sync_clk}
add wave -noreg -logic {/dds_interface_tb/i_dut/dds_io_update}
add wave -noreg -logic {/dds_interface_tb/i_dut/dds_duration_valid}
add wave -noreg -logic {/dds_interface_tb/i_dut/dds_sweep_rdy}
add wave -noreg -logic {/dds_interface_tb/i_dut/jam_terminate_line}
add wave -noreg -literal {/dds_interface_tb/i_dut/fsm_jam_rd_next}
add wave -noreg -literal {/dds_interface_tb/i_dut/fsm_jam_rd}
add wave -noreg -literal {/dds_interface_tb/i_dut/fsm_dds_parallel}
add wave -noreg -logic {/dds_interface_tb/i_dut/jam_dds_dout_valid}
add wave -noreg -logic {/dds_interface_tb/i_dut/jam_rd_en}
add wave -noreg -hexadecimal -literal {/dds_interface_tb/i_dut/jam_data}
add wave -noreg -hexadecimal -literal {/dds_interface_tb/i_dut/wait_count}
add wave -noreg -virtual "dds_d"  {/dds_interface_tb/i_dut/dds_d(31)} {/dds_interface_tb/i_dut/dds_d(30)} {/dds_interface_tb/i_dut/dds_d(29)} {/dds_interface_tb/i_dut/dds_d(28)} {/dds_interface_tb/i_dut/dds_d(27)} {/dds_interface_tb/i_dut/dds_d(26)} {/dds_interface_tb/i_dut/dds_d(25)} {/dds_interface_tb/i_dut/dds_d(24)} {/dds_interface_tb/i_dut/dds_d(23)} {/dds_interface_tb/i_dut/dds_d(22)} {/dds_interface_tb/i_dut/dds_d(21)} {/dds_interface_tb/i_dut/dds_d(20)} {/dds_interface_tb/i_dut/dds_d(19)} {/dds_interface_tb/i_dut/dds_d(18)} {/dds_interface_tb/i_dut/dds_d(17)} {/dds_interface_tb/i_dut/dds_d(16)}
add wave -noreg -virtual "dds_a"  {/dds_interface_tb/i_dut/dds_d(15)} {/dds_interface_tb/i_dut/dds_d(14)} {/dds_interface_tb/i_dut/dds_d(13)} {/dds_interface_tb/i_dut/dds_d(12)} {/dds_interface_tb/i_dut/dds_d(11)} {/dds_interface_tb/i_dut/dds_d(10)} {/dds_interface_tb/i_dut/dds_d(9)} {/dds_interface_tb/i_dut/dds_d(8)}
add wave -noreg -virtual "dds_wr_n"  {/dds_interface_tb/i_dut/dds_d(2)}
add wave -noreg -logic {/dds_interface_tb/i_dut/dds_restart_prep}
add wave -noreg -logic {/dds_interface_tb/i_dut/dds_restart_exec}
add wave -noreg -logic {/dds_interface_tb/i_dut/reload_next_line}
add wave -noreg -logic {/dds_interface_tb/i_dut/dds_restart_exec_hold}
add wave -noreg -hexadecimal -literal {/dds_interface_tb/i_dut/io_update_count}
add wave -noreg -hexadecimal -literal {/dds_interface_tb/i_dut/io_update_next_dur}
add wave -noreg -hexadecimal -literal {/dds_interface_tb/i_dut/io_update_next_dur_adj}
cursor "Cursor 1" 0ps  
cursor "Cursor 7" 775245ns  
transcript on

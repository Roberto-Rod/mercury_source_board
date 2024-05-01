onerror { resume }
transcript off
add wave -noreg -logic {/jam_engine_core_tb/uut/reg_clk}
add wave -noreg -logic {/jam_engine_core_tb/dds_sync_clk}
add wave -noreg -logic {/jam_engine_core_tb/uut/shadow_select}
add wave -noreg -logic {/jam_engine_core_tb/uut/vswr_line_ack}
add wave -noreg -logic {/jam_engine_core_tb/uut/vswr_line_req}
add wave -noreg -logic {/jam_engine_core_tb/uut/vswr_line_req_s}
add wave -noreg -logic {/jam_engine_core_tb/uut/vswr_line_req_latch}
add wave -noreg -logic {/jam_engine_core_tb/uut/vswr_line_ack_u}
add wave -noreg -logic {/jam_engine_core_tb/uut/jam_rd_en}
add wave -noreg -literal {/jam_engine_core_tb/uut/fsm_jam}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/line_repeat_count}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/line_repeat_nr}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/line_count}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/line_addr}
add wave -noreg -logic {/jam_engine_core_tb/uut/line_addr_1st}
add wave -noreg -logic {/jam_engine_core_tb/uut/line_addr_valid}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/mem_addr}
add wave -noreg -logic {/jam_engine_core_tb/mem_addr_valid}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/mem_data}
add wave -noreg -logic {/jam_engine_core_tb/mem_data_valid}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/mem_data_dly}
add wave -noreg -logic {/jam_engine_core_tb/uut/mem_data_valid_dly}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/jam_line}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/jam_line_r}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/mem_data_r}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/amplitude_data_in_1}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/temp_comp_mult_1}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/temp_comp_offs_1}
add wave -noreg -logic {/jam_engine_core_tb/uut/dblr_line_1}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/scaled_data_2}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/offset_data_3}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/amplitude_data_out_4}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/jam_line_dly}
add wave -noreg -logic {/jam_engine_core_tb/uut/line_addr_1st_dly}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/fifo_wr_data}
add wave -noreg -logic {/jam_engine_core_tb/uut/fifo_wr_en}
add wave -noreg -logic {/jam_engine_core_tb/uut/jam_fifo_empty}
add wave -noreg -logic {/jam_engine_core_tb/uut/fifo_prog_full}
add wave -noreg -logic {/jam_engine_core_tb/uut/jam_srst}
add wave -noreg -logic {/jam_engine_core_tb/uut/jam_terminate_line}
add wave -noreg -hexadecimal -literal {/jam_engine_core_tb/uut/jam_data}
add wave -noreg -logic {/jam_engine_core_tb/uut/jam_fifo_empty}
add wave -noreg -logic {/jam_engine_core_tb/uut/jam_rd_en}
cursor "Cursor 3" 162358ps  
transcript on

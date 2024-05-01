onerror { resume }
transcript off
add wave -noreg -logic {/dds_interface_jam_engine_tb/reg_clk}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/reg_mosi_ecm}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/shadow_select_s}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_jam_engine/jam_srst}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/dds_srst}
add wave -noreg -logic {/dds_interface_jam_engine_tb/dds_sync_clk}
add wave -noreg -literal {/dds_interface_jam_engine_tb/i_dds_interface/fsm_jam_rd}
add wave -noreg -literal {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/fsm_jam}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/jam_line}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/line_repeat_count}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/line_repeat_nr}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/line_addr_repeat}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_dds_interface/dds_restart_exec}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_dds_interface/dds_restart_exec_s}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_dds_interface/first_line}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_dds_interface/dds_sweep_rdy}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_dds_interface/dds_restart_prep}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_dds_interface/dds_restart_prep_s}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_dds_interface/dds_restart_exec_hold}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_dds_interface/restart_prepared}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_dds_interface/restart_index}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/jam_fifo_empty}
add wave -noreg -logic {/dds_interface_jam_engine_tb/jam_rd_en}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/jam_data}
add wave -noreg -logic {/dds_interface_jam_engine_tb/jam_terminate_line}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/dds_d}
add wave -noreg -virtual "dds_wr_n"  {/dds_interface_jam_engine_tb/dds_d(2)}
add wave -noreg -virtual "dds_data"  {/dds_interface_jam_engine_tb/dds_d(31)} {/dds_interface_jam_engine_tb/dds_d(30)} {/dds_interface_jam_engine_tb/dds_d(29)} {/dds_interface_jam_engine_tb/dds_d(28)} {/dds_interface_jam_engine_tb/dds_d(27)} {/dds_interface_jam_engine_tb/dds_d(26)} {/dds_interface_jam_engine_tb/dds_d(25)} {/dds_interface_jam_engine_tb/dds_d(24)} {/dds_interface_jam_engine_tb/dds_d(23)} {/dds_interface_jam_engine_tb/dds_d(22)} {/dds_interface_jam_engine_tb/dds_d(21)} {/dds_interface_jam_engine_tb/dds_d(20)} {/dds_interface_jam_engine_tb/dds_d(19)} {/dds_interface_jam_engine_tb/dds_d(18)} {/dds_interface_jam_engine_tb/dds_d(17)} {/dds_interface_jam_engine_tb/dds_d(16)}
add wave -noreg -virtual "dds_addr"  {/dds_interface_jam_engine_tb/dds_d(15)} {/dds_interface_jam_engine_tb/dds_d(14)} {/dds_interface_jam_engine_tb/dds_d(13)} {/dds_interface_jam_engine_tb/dds_d(12)} {/dds_interface_jam_engine_tb/dds_d(11)} {/dds_interface_jam_engine_tb/dds_d(10)} {/dds_interface_jam_engine_tb/dds_d(9)} {/dds_interface_jam_engine_tb/dds_d(8)}
add wave -noreg -logic {/dds_interface_jam_engine_tb/dds_io_update}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/fifo_wr_data}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/fifo_wr_en}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/blk_mem_wea}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/blk_mem_addra}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/blk_mem_dina}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/mem_addr}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/mem_addr_valid}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/mem_data_dly}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/mem_data_valid_dly}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/blk_mem_addrb}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/blk_mem_doutb}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/mem_data}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/mem_data_valid}
add wave -noreg -literal {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/fsm_jam}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/line_addr}
add wave -noreg -logic {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/line_addr_valid}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/start_line_addr}
add wave -noreg -hexadecimal -literal {/dds_interface_jam_engine_tb/i_jam_engine/i_jam_engine_core/end_line_addr}
cursor "Cursor 1" 633213ps  
cursor "Cursor 2" 1893962301ps  
cursor "Cursor 8" 1941977161ps  
transcript on

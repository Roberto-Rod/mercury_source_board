onerror { resume }
transcript off
view wave
add wave -noreg -vgroup "REG VVC"          {/general_registers_vvc_tb/i_test_harness/i_reg_vvc/transaction_info_for_waveview}\
                                           {/general_registers_vvc_tb/i_test_harness/reg_clk}\
                                           {/general_registers_vvc_tb/i_test_harness/reg_srst}\
                                           {/general_registers_vvc_tb/i_test_harness/i_reg_vvc/reg_vvc_master_if}
transcript on
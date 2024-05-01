onerror { resume }
transcript off
view wave
add wave -noreg -vgroup "REG MASTER VVC"       {/drm_reg_bridge_vvc_tb/i_test_harness/i_reg_vvc_master/transaction_info_for_waveview}\
                                               {/drm_reg_bridge_vvc_tb/i_test_harness/reg_clk}\
                                               {/drm_reg_bridge_vvc_tb/i_test_harness/reg_srst}\
                                               {/drm_reg_bridge_vvc_tb/i_test_harness/i_reg_vvc_master/reg_vvc_master_if}

add wave -noreg -vgroup "REG SLAVE VVC"        {/drm_reg_bridge_vvc_tb/i_test_harness/reg_clk}\
                                               {/drm_reg_bridge_vvc_tb/i_test_harness/reg_srst}\
                                               {/drm_reg_bridge_vvc_tb/i_test_harness/s_reg_mosi}\
                                               {/drm_reg_bridge_vvc_tb/i_test_harness/s_reg_miso}
                                               
add wave -noreg -vgroup "LOCALLINK MASTER VVC" {/drm_reg_bridge_vvc_tb/i_test_harness/i_locallink_master/transaction_info_for_waveview}\
                                               {/drm_reg_bridge_vvc_tb/i_test_harness/link_clk}\
                                               {/drm_reg_bridge_vvc_tb/i_test_harness/link_srst}\
                                               {/drm_reg_bridge_vvc_tb/i_test_harness/i_locallink_master/locallink_vvc_if}
                                               
add wave -noreg -vgroup "LOCALLINK SLAVE VVC"  {/drm_reg_bridge_vvc_tb/i_test_harness/i_locallink_slave/transaction_info_for_waveview}\
                                               {/drm_reg_bridge_vvc_tb/i_test_harness/link_clk}\
                                               {/drm_reg_bridge_vvc_tb/i_test_harness/link_srst}\
                                               {/drm_reg_bridge_vvc_tb/i_test_harness/i_locallink_slave/locallink_vvc_if}
transcript on
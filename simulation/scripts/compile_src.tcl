# Compile design sources
vcom -nowarn DAGGEN_0523 ../../src/packages/mercury_pkg.vhd
vcom -nowarn DAGGEN_0523 ../../src/packages/mercury_source_board_version.vhd
vcom -nowarn DAGGEN_0523 ../../src/packages/mercury_source_board_build_id.vhd
vcom -nowarn DAGGEN_0523 ../../src/clocks/mercury_clocks.vhd
vcom -nowarn DAGGEN_0523 ../../src/cpu_spi_slave/cpu_spi_slave.vhd
vcom -nowarn DAGGEN_0523 ../../src/i2c_master/i2c_master_cmd_ctrl.vhd
vcom -nowarn DAGGEN_0523 ../../src/i2c_master/i2c_master_top.vhd
vcom -nowarn DAGGEN_0523 ../../src/general_registers/general_registers.vhd
vcom -nowarn DAGGEN_0523 ../../src/dds_interface/dds_interface.vhd
vcom -nowarn DAGGEN_0523 ../../src/synth_interface/synth_interface.vhd
vcom -nowarn DAGGEN_0523 ../../src/rf_ctrl/rf_ctrl.vhd
vcom -nowarn DAGGEN_0523 ../../src/prbs_gen/prbs_gen.vhd
vcom -nowarn DAGGEN_0523 ../../src/jam_engine/jam_engine_core.vhd
vcom -nowarn DAGGEN_0523 ../../src/jam_engine/jam_engine_top.vhd
vcom -nowarn DAGGEN_0523 ../../src/pwr_mon/pwr_mon_spi_master.vhd
vcom -nowarn DAGGEN_0523 ../../src/pwr_mon/pwr_mon_moving_avg.vhd
vcom -nowarn DAGGEN_0523 ../../src/pwr_mon/pwr_mon_block_avg.vhd
vcom -nowarn DAGGEN_0523 ../../src/pwr_mon/pwr_mon_capture.vhd
vcom -nowarn DAGGEN_0523 ../../src/pwr_mon/pwr_mon_top.vhd
vcom -nowarn DAGGEN_0523 ../../src/vswr_engine/vswr_miso_mux.vhd
vcom -nowarn DAGGEN_0523 ../../src/vswr_engine/vswr_engine.vhd
vcom -nowarn DAGGEN_0523 ../../src/pps_sync/pps_sync.vhd
vcom -nowarn DAGGEN_0523 ../../src/blank_ctrl/blank_ctrl.vhd
vcom -nowarn DAGGEN_0523 ../../src/dac_ctrl/i2c_dac_cmd_ctrl.vhd
vcom -nowarn DAGGEN_0523 ../../src/dac_ctrl/dac_ctrl.vhd
vcom -nowarn DAGGEN_0523 ../../src/dock_comms/dock_packet_gen.vhd
vcom -nowarn DAGGEN_0523 ../../src/dock_comms/dock_packet_decode.vhd
vcom -nowarn DAGGEN_0523 ../../src/dock_comms/dock_comms.vhd
vcom -nowarn DAGGEN_0523 ../../src/pa_management/pa_management.vhd
vcom -nowarn DAGGEN_0523 ../../src/timing_protocol/tp_transition_ram.vhd
vcom -nowarn DAGGEN_0523 ../../src/timing_protocol/tp_dds_restart.vhd
vcom -nowarn DAGGEN_0523 ../../src/timing_protocol/timing_protocol.vhd
vcom -nowarn DAGGEN_0523 ../../src/freq_trim/freq_trim.vhd
# Aurora package
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_aurora_pkg.vhd
# Aurora Lane Modules  
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_chbond_count_dec_4byte.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_err_detect_4byte.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_lane_init_sm_4byte.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_sym_dec_4byte.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_sym_gen_4byte.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_aurora_lane_4byte.vhd
# Global Logic Modules
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_channel_err_detect.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_channel_init_sm.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_idle_and_ver_gen.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_global_logic.vhd 
# TX LocalLink User Interface modules
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_tx_ll_control.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_tx_ll_datapath.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_tx_ll.vhd
# RX_LL Pdu Modules
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_left_align_control.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_left_align_mux.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_output_mux.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_output_switch_control.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_rx_ll_deframer.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_sideband_output.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_storage_ce_control.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_storage_count_control.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_storage_mux.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_storage_switch_control.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_valid_data_counter.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_rx_ll_pdu_datapath.vhd
# RX_LL top level
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/core/drm_aurora_rx_ll.vhd
# GT Modules
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/gt/drm_aurora_tile.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/gt/drm_aurora_transceiver_wrapper.vhd
# Aurora Core Top Level
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/drm_aurora.vhd
# Aurora Support Modules
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/support/drm_aurora_cc_module.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/support/drm_aurora_clock_module.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/support/drm_aurora_frame_check.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/support/drm_aurora_frame_gen.vhd
# Aurora Wrapper
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_aurora/drm_aurora_wrapper.vhd
# DRM Interface
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/bridge_fifo_scheduler.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_reg_bridge.vhd
vcom -nowarn DAGGEN_0523 ../../src/drm_interface/drm_interface_top.vhd

# Top Level
vcom -nowarn DAGGEN_0523 ../../src/top_level/mercury_source_board_top.vhd

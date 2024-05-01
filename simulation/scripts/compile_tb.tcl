# Compile testbenches
vcom -nowarn DAGGEN_0523 ../../tb/clocks/mercury_clocks_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/cpu_spi_slave/cpu_spi_slave_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/dds_interface/dds_interface_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/dock_comms/dock_packet_decode_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/dock_comms/dock_comms_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/general_registers/general_registers_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/i2c_master/i2c_master_cmd_ctrl_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/jam_engine/jam_engine_core_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/jam_engine/jam_engine_top_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/pps_sync/pps_sync_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/prbs_gen/prbs_gen_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/pwr_mon/mult_acc_pwrmon_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/pwr_mon/pwr_mon_capture_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/pwr_mon/pwr_mon_spi_master_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/pwr_mon/pwr_mon_block_avg_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/pwr_mon/pwr_mon_moving_avg_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/rf_ctrl/rf_ctrl_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/synth_interface/synth_interface_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/vswr_engine/vswr_engine_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/timing_protocol/timing_protocol_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/timing_protocol/tp_dds_restart_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/freq_trim/freq_trim_tb.vhd
vcom -nowarn DAGGEN_0523 ../../tb/drm_interface/drm_reg_bridge_tb.vhd
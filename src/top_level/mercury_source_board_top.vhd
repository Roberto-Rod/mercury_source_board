----------------------------------------------------------------------------------
--! @file mercury_source_board_top.vhd
--! @brief Top-level module for Source Board FPGA
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
--! @version See Git logs
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.mercury_pkg.all;
use work.reg_pkg.all;

entity mercury_source_board_top is
    port (
        -- 10MHz Clock
        clk_10m             : in  std_logic;

        -- TCXO DAC
        dac_scl             : inout std_logic;
        dac_sda             : inout std_logic;
        dac_ldac_n          : out std_logic;

        -- Power Supply Control
        pwr_en_1v8          : out std_logic;

        -- Slave SPI Bus
        spi_cpu_rst_n       : in  std_logic;
        spi_cpu_clk         : in std_logic;
        spi_cpu_cs_n        : in std_logic;
        spi_cpu_rdy_rd      : out std_logic;
        spi_cpu_error       : out std_logic;
        spi_cpu_mosi        : in std_logic;
        spi_cpu_miso        : out std_logic;

        -- GPIO / CPU Interrupts
        ext_gpio            : inout  std_logic_vector(7 downto 0);
        cpu_eint            : out  std_logic_vector(1 downto 0);
        ctl_gpio            : in std_logic_vector(3 downto 0);
        cpu_gpio            : out std_logic_vector(5 downto 2);

        -- DDS (AD9914) signals
        dds_ext_pwr_dwn     : out std_logic;                        --! DDS power down
        dds_reset           : out std_logic;                        --! DDS asynchronous reset signal, active high
        dds_d               : inout std_logic_vector(31 downto 0);  --! DDS data/address/serial pins
        dds_osk             : out std_logic;                        --! DDS On-Off Shift Keying (OSK) output
        dds_io_update       : out std_logic;                        --! IO Update line
        dds_dr_over         : in std_logic;                         --! "Digital ramp over" signal
        dds_dr_hold         : out std_logic;                        --! "Digital ramp hold" signal
        dds_dr_ctl          : out std_logic;                        --! "Digital ramp control" signal
        dds_sync_clk        : in std_logic;                         --! DDS sync clock signal
        dds_ps              : out std_logic_vector(2 downto 0);     --! DDS profile select
        dds_f               : out std_logic_vector(3 downto 0);     --! DDS function - selects SPI/parallel interface

        -- Synth signals
        synth_sclk          : out std_logic;                        --! Serial clock into synth
        synth_data          : out std_logic;                        --! Serial data into synth
        synth_le            : out std_logic;                        --! Load Enable. Loads data into register
        synth_ce            : out std_logic;                        --! Chip Enable. Logic low powers down the device
        synth_ld            : in std_logic;                         --! Lock Detect. Logic high indicates PLL lock
        synth_pdrf_n        : out std_logic;                        --! RF Power-Down. Logic low mutes the RF outputs
        synth_muxout        : in std_logic;                         --! Multiplexer output from synth
        synth_refclk        : out std_logic;                        --! Synth reference clock

        -- External Blanking Input/Output
        blank_in_n          : in std_logic;                         --! External blanking input
        blank_out_n         : out std_logic;                        --! External blanking output
        
        -- Tx/Rx Switch Control
        tx_rx_ctrl          : inout std_logic;                      --! External Tx/Rx switch control (tri-state when not jamming)

        -- External 1PPS Input/Output
        ext_pps_in          : in std_logic;                         --! External 1PPS input
        ext_pps_out         : out std_logic;                        --! External 1PPS output

        -- RF stage control
        rf_att_v            : out std_logic_vector(2 downto 1);     --! Source board RF attenuator control bits
        rf_sw_v_a           : out std_logic_vector(2 downto 1);     --! Source board RF blanking switch control bits
        rf_sw_v_b           : out std_logic_vector(2 downto 1);     --! Source board RF output switch control bits

        -- Daughter board control
        dgtr_rf_sw_ctrl     : out std_logic_vector(6 downto 0);     --! Daughter board switch control
        dgtr_rf_att_ctrl    : out std_logic_vector(8 downto 0);     --! Daughter board attenuator control
        dgtr_pwr_en_5v5     : out std_logic;                        --! Daughter board 5V5 enable (high)
        dgtr_pwr_gd_5v5     : in std_logic;                         --! Daughter board 5V5 good (high)
        dgtr_id             : in std_logic_vector(3 downto 0);      --! Daughter board ID

        -- Internal PA Channel A control/status
        int_pa_mosi_a       : out pa_management_mosi_type;
        int_pa_miso_a       : in pa_management_miso_type;
        int_pa_bidir_a      : inout pa_management_bidir_type;

        -- Dock Channel A Comms
        dock_comms_ro_a     : in std_logic;
        dock_comms_re_n_a   : out std_logic;
        dock_comms_de_a     : out std_logic;
        dock_comms_di_a     : out std_logic;

        -- Dock Channel A Blank Control
        dock_blank_re_n_a   : out std_logic;
        dock_blank_de_a     : out std_logic;
        dock_blank_di_a     : out std_logic;
        
        -- MGT Clock Enable
        mgt_clk_en          : out std_logic;
        
        -- MGT Clock
        mgt_clk_p           : in std_logic;
        mgt_clk_n           : in std_logic;

        -- MGT I/O
        mgt_rx_p            : in std_logic;
        mgt_rx_n            : in std_logic;
        mgt_tx_p            : out std_logic;
        mgt_tx_n            : out std_logic;

        -- Debug LEDs
        debug_led           : out  std_logic_vector (1 downto 0);

        -- Hardware version/mod-level
        hw_vers             : in std_logic_vector(2 downto 0);
        hw_mod              : in std_logic_vector(2 downto 0)
    );
end mercury_source_board_top;

architecture rtl of mercury_source_board_top is
    -- Constants
    constant LINE_ADDR_BITS         : natural := 15;

    -- Buffered clocks
    signal dds_sync_clk_c           : std_logic;
    signal spi_cpu_clk_c            : std_logic;
    signal spi_cpu_ce               : std_logic;

    -- Register buses
    signal reg_clk                  : std_logic;
    signal reg_srst                 : std_logic;
    signal reg_mosi                 : reg_mosi_type;
    signal reg_miso                 : reg_miso_type;
    signal reg_miso_mux_1           : reg_miso_type;
    signal reg_miso_mux_2           : reg_miso_type;
    signal reg_miso_gen             : reg_miso_type;
    signal reg_miso_dac             : reg_miso_type;
    signal reg_miso_dds             : reg_miso_type;
    signal reg_miso_synth           : reg_miso_type;
    signal reg_miso_rf_ctrl         : reg_miso_type;
    signal reg_miso_blank_ctrl      : reg_miso_type;
    signal reg_miso_pa_mgmt         : reg_miso_type;
    signal reg_miso_pps_sync        : reg_miso_type;
    signal reg_miso_jam_eng         : reg_miso_type;
    signal reg_miso_vswr_eng        : reg_miso_type;
    signal reg_miso_tp              : reg_miso_type;
    signal reg_miso_freq_trim       : reg_miso_type;
    signal reg_miso_drm_if          : reg_miso_type;
    signal reg_miso_dummy           : reg_miso_type;
    
    -- DRM Mastered Register Bus
    signal reg_mosi_drm             : reg_mosi_type;
    signal reg_miso_drm             : reg_miso_type;
    
    -- Receive test mode active-high enable signal
    signal rx_test_en               : std_logic;
    
    -- Jamming engine active-low enable signal
    signal jam_en_n                 : std_logic;
    
    -- Jamming engine <-> DDS interface
    signal jam_rd_en                : std_logic;
    signal jam_data                 : std_logic_vector(31 downto 0);
    signal jam_terminate_line       : std_logic;
    signal jam_fifo_empty           : std_logic;

    -- VSWR engine signals
    signal vswr_line_addr           : std_logic_vector(LINE_ADDR_BITS-1 downto 0);
    signal vswr_line_req            : std_logic;
    signal vswr_line_ack            : std_logic;
    signal vswr_mosi                : vswr_mosi_type;
    signal vswr_miso                : vswr_miso_type;
    signal vswr_line_start          : std_logic;

    -- RF control signals
    signal jam_rf_ctrl              : std_logic_vector(31 downto 0);
    signal jam_rf_ctrl_valid        : std_logic;

    -- Internal blanking signals (reg_clk domain)
    signal int_blank_n              : std_logic;    
    signal tp_ext_blank_n           : std_logic;
    signal vswr_blank_rev_n         : std_logic;
    signal vswr_blank_all_n         : std_logic;
    signal tp_async_blank_n         : std_logic;
    signal jam_blank_n              : std_logic;
    
    -- Internal Tx/Rx control
    signal tx_rx_ctrl_int           : std_logic;
    signal tx_rx_ctrl_o             : std_logic;

    -- Internal 1PPS signals (reg_clk domain)
    signal int_pps                  : std_logic;
    signal ext_pps_present          : std_logic;
    
    -- Clock count (between 1PPS)
    signal clk_count                : std_logic_vector(26 downto 0);
    signal clk_count_valid          : std_logic;
    
    -- Frequency trimming DAC control
    signal dac_val                  : std_logic_vector(11 downto 0);
    signal dac_val_valid            : std_logic;
    
    -- Timing Protocol control signals
    signal tp_sync_en               : std_logic;
    signal dds_restart_prep         : std_logic;
    signal dds_restart_exec         : std_logic;
    
    signal channel_up               : std_logic;
begin
    --------------------------------------
    -- Fixed outputs
    --------------------------------------
    debug_led(0) <= not channel_up;
    debug_led(1) <= '1';
    cpu_eint     <= (others => '1');
    mgt_clk_en   <= '1';

    -------------------
    -- Hook up CPU GPIO
    -------------------
    cpu_gpio <= ctl_gpio;
    
    -----------------------------
    -- Tx/Rx Control Tri-State --
    -----------------------------
    tx_rx_ctrl <= tx_rx_ctrl_o when (jam_en_n = '0') else 'Z';

    i_cpu_spi_slave: entity work.cpu_spi_slave
    port map (
        -- Slave SPI Bus
        spi_rst_n           => spi_cpu_rst_n,
        spi_clk             => spi_cpu_clk_c,
        spi_ce              => spi_cpu_ce,
        spi_cs_n            => spi_cpu_cs_n,
        spi_rdy_rd          => spi_cpu_rdy_rd,
        spi_error           => spi_cpu_error,
        spi_mosi            => spi_cpu_mosi,
        spi_miso            => spi_cpu_miso,

        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_miso            => reg_miso,
        reg_mosi            => reg_mosi
    );

    reg_miso_dummy.data <= (others => '0');
    reg_miso_dummy.ack  <= '0';

    i_general_registers: entity work.general_registers
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_miso            => reg_miso_gen,
        reg_mosi            => reg_mosi,

        -- External GPIO
        ext_gpio            => ext_gpio,

        -- Hardware version/mod-level
        hw_vers             => hw_vers,
        hw_mod              => hw_mod
    );

    i_dac_ctrl: entity work.dac_ctrl
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_miso            => reg_miso_dac,
        reg_mosi            => reg_mosi,

        -- Frequency trimming control
        dac_val_i           => dac_val,
        dac_val_valid_i     => dac_val_valid,

		-- I2C I/O Signals
		scl                 => dac_scl,
        sda                 => dac_sda,

        -- Other DAC signals
        ldac_n              => dac_ldac_n
    );

    i_dds_interface: entity work.dds_interface
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso_dds,

        -- Jamming engine interface
        jam_rd_en           => jam_rd_en,
        jam_data            => jam_data,
        jam_terminate_line  => jam_terminate_line,
        jam_fifo_empty      => jam_fifo_empty,
        jam_en_n            => jam_en_n,
        jam_rf_ctrl         => jam_rf_ctrl,
        jam_rf_ctrl_valid   => jam_rf_ctrl_valid,

        -- VSWR engine signals
        vswr_line_start     => vswr_line_start,

        -- Blanking signals
        jam_blank_out_n     => jam_blank_n,
        blank_in_n          => int_blank_n,
        
        -- Internal 1PPS signal
        int_pps_i           => int_pps,
        
        -- Timing Protocol control
        tp_sync_en          => tp_sync_en,
        dds_restart_prep    => dds_restart_prep,
        dds_restart_exec    => dds_restart_exec,

        -- DDS core power supply enable
        pwr_en_1v8          => pwr_en_1v8,

        -- AD9914 signals
        dds_ext_pwr_dwn     => dds_ext_pwr_dwn,
        dds_reset           => dds_reset,
        dds_d               => dds_d,
        dds_osk             => dds_osk,
        dds_io_update       => dds_io_update,
        dds_dr_over         => dds_dr_over,
        dds_dr_hold         => dds_dr_hold,
        dds_dr_ctl          => dds_dr_ctl,
        dds_sync_clk        => dds_sync_clk_c,
        dds_ps              => dds_ps,
        dds_f               => dds_f,
        
        -- Daughter Board ID
        dgtr_id             => dgtr_id
    );

    i_synth_interface: entity work.synth_interface
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso_synth,

        -- Synth Signals
        synth_sclk          => synth_sclk,
        synth_data          => synth_data,
        synth_le            => synth_le,
        synth_ce            => synth_ce,
        synth_ld            => synth_ld,
        synth_pdrf_n        => synth_pdrf_n,
        synth_muxout        => synth_muxout
     );

    i_rf_ctrl: entity work.rf_ctrl
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso_rf_ctrl,

        -- RF stage control
        rf_att_v            => rf_att_v,
        rf_sw_v_a           => rf_sw_v_a,
        rf_sw_v_b           => rf_sw_v_b,

        -- Daughter board control
        dgtr_rf_sw_ctrl     => dgtr_rf_sw_ctrl,
        dgtr_rf_att_ctrl    => dgtr_rf_att_ctrl,
        dgtr_pwr_en_5v5     => dgtr_pwr_en_5v5,
        dgtr_pwr_gd_5v5     => dgtr_pwr_gd_5v5,
        dgtr_id             => dgtr_id,

        -- Blanking Input
        int_blank_n         => int_blank_n,

        -- Jamming engine signals
        jam_en_n            => jam_en_n,
        jam_rf_ctrl         => jam_rf_ctrl,
        jam_rf_ctrl_valid   => jam_rf_ctrl_valid
    );

    i_blank_ctrl: entity work.blank_ctrl
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso_blank_ctrl,

        -- Blanking inputs
        ext_blank_in_n      => blank_in_n,
        jam_blank_n         => jam_blank_n,
        vswr_blank_rev_n    => vswr_blank_rev_n,
        vswr_blank_all_n    => vswr_blank_all_n,
        tp_async_blank_n    => tp_async_blank_n,

        -- Blanking outputs
        int_blank_n         => int_blank_n,
        tp_ext_blank_n      => tp_ext_blank_n,
        ext_blank_out_n     => blank_out_n,
        
        -- Tx/Rx Control in/out
        tx_rx_ctrl_in       => tx_rx_ctrl_int,
        tx_rx_ctrl_out      => tx_rx_ctrl_o
    );

    i_pa_management : entity work.pa_management
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso_pa_mgmt,

        -- VSWR Engine Bus
        vswr_mosi           => vswr_mosi,
        vswr_miso           => vswr_miso,

        -- Blanking Control
        int_blank_n         => int_blank_n,

        -- Internal PA Channel A control/status
        int_pa_mosi_a       => int_pa_mosi_a,
        int_pa_miso_a       => int_pa_miso_a,
        int_pa_bidir_a      => int_pa_bidir_a,

        -- Dock Channel A Comms
        dock_comms_ro_a     => dock_comms_ro_a,
        dock_comms_re_n_a   => dock_comms_re_n_a,
        dock_comms_de_a     => dock_comms_de_a,
        dock_comms_di_a     => dock_comms_di_a,

        -- Dock Channel A Blank Control
        dock_blank_re_n_a   => dock_blank_re_n_a,
        dock_blank_de_a     => dock_blank_de_a,
        dock_blank_di_a     => dock_blank_di_a
    );

    i_jam_engine: entity work.jam_engine_top
    generic map( LINE_ADDR_BITS => LINE_ADDR_BITS )
    port map(        
        -- DDS clock
        dds_sync_clk        => dds_sync_clk_c,
        
        -- Register clock/reset
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        
        -- ECM register Bus
        reg_mosi_ecm        => reg_mosi,
        reg_miso_ecm        => reg_miso_jam_eng,
        
        -- DRM register Bus
        reg_mosi_drm        => reg_mosi_drm,
        reg_miso_drm        => reg_miso_drm,
        
        -- Receive test mode enable
        rx_test_en          => rx_test_en,

        -- Jamming engine sync reset
        jam_en_n            => jam_en_n,

        -- VSWR engine signals
        vswr_line_addr      => vswr_line_addr,
        vswr_line_req       => vswr_line_req,
        vswr_line_ack       => vswr_line_ack,

        -- DDS interface
        jam_rd_en           => jam_rd_en,
        jam_data            => jam_data,
        jam_terminate_line  => jam_terminate_line,
        jam_fifo_empty      => jam_fifo_empty
     );

    i_vswr_engine: entity work.vswr_engine
    generic map( LINE_ADDR_BITS => LINE_ADDR_BITS )
    port map(
        -- Register Bus
        reg_clk             => reg_clk ,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso_vswr_eng,

        -- Jamming engine enable signal
        jam_en_n            => jam_en_n,
        
        -- Blanking input
        int_blank_n         => int_blank_n,

        -- Blanking outputs
        blank_out_rev_n     => vswr_blank_rev_n,
        blank_out_all_n     => vswr_blank_all_n,

        -- VSWR engine signals
        vswr_line_addr      => vswr_line_addr,
        vswr_line_req       => vswr_line_req,
        vswr_line_ack       => vswr_line_ack,
        vswr_mosi           => vswr_mosi,
        vswr_miso           => vswr_miso,
        vswr_line_start     => vswr_line_start,

        -- 1PPS signals
        int_pps             => int_pps
    );

    i_pps_sync: entity work.pps_sync
    port map(
        -- Register Bus
        reg_clk_i           => reg_clk,
        reg_srst_i          => reg_srst,
        reg_mosi_i          => reg_mosi,
        reg_miso_o          => reg_miso_pps_sync,

        -- 1PPS signals
        ext_pps_i           => ext_pps_in,
        ext_pps_o           => ext_pps_out,
        int_pps_o           => int_pps,
        ext_pps_present_o   => ext_pps_present,
        
        -- Clock count out
        clk_count_o         => clk_count,
        clk_count_valid_o   => clk_count_valid
    );
    
    i_freq_trim: entity work.freq_trim
    generic map (
        CLK_CNT_BITS        => clk_count'length
    )
    port map (
        -- Register Bus
        reg_clk_i           => reg_clk,
        reg_srst_i          => reg_srst,
        reg_mosi_i          => reg_mosi,
        reg_miso_o          => reg_miso_freq_trim,

        -- Frequency error
        clk_count_i         => clk_count,
        clk_count_valid_i   => clk_count_valid,
        
        -- VC-TCXO Control
        dac_val_o           => dac_val,
        dac_val_valid_o     => dac_val_valid
    );

    i_timing_protocol: entity work.timing_protocol
    port map(
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso_tp,

        -- Receive test mode enable
        rx_test_en          => rx_test_en,
        
        -- Asynchronous Blanking Output
        tp_ext_blank_n      => tp_ext_blank_n,
        tp_async_blank_n    => tp_async_blank_n,
        
        -- Tx/Rx Switch Control
        tx_rx_ctrl          => tx_rx_ctrl_int,
        
        -- DDS Line Restart
        dds_restart_prep    => dds_restart_prep,
        dds_restart_exec    => dds_restart_exec,

        -- Synchronous TP Enable
        tp_sync_en          => tp_sync_en,

        -- 1PPS Input
        int_pps             => int_pps,
        ext_pps_present     => ext_pps_present
    );
    
    i_drm_interface: entity work.drm_interface_top
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi_ecm        => reg_mosi,
        reg_miso_ecm        => reg_miso_drm_if,
        reg_mosi_drm        => reg_mosi_drm,
        reg_miso_drm        => reg_miso_drm,
        
        -- MGT Clock
        mgt_clk_p           => mgt_clk_p,
        mgt_clk_n           => mgt_clk_n,

        -- MGT I/O
        mgt_rx_p            => mgt_rx_p,
        mgt_rx_n            => mgt_rx_n,
        mgt_tx_p            => mgt_tx_p,
        mgt_tx_n            => mgt_tx_n,
        
        channel_up_o        => channel_up
    );

    i_reg_miso_mux_1: entity work.reg_miso_mux6
    port map (
        -- Clock
        reg_clk             => reg_clk,

        -- Input data/valid
        reg_miso_i_1        => reg_miso_gen,
        reg_miso_i_2        => reg_miso_dds,
        reg_miso_i_3        => reg_miso_synth,
        reg_miso_i_4        => reg_miso_rf_ctrl,
        reg_miso_i_5        => reg_miso_pa_mgmt,
        reg_miso_i_6        => reg_miso_pps_sync,

        -- Output data/valid
        reg_miso_o          => reg_miso_mux_1
    );

    i_reg_miso_mux_2: entity work.reg_miso_mux6
    port map (
        -- Clock
        reg_clk             => reg_clk,

        -- Input data/valid
        reg_miso_i_1        => reg_miso_jam_eng,
        reg_miso_i_2        => reg_miso_vswr_eng,
        reg_miso_i_3        => reg_miso_blank_ctrl,
        reg_miso_i_4        => reg_miso_dac,
        reg_miso_i_5        => reg_miso_tp,
        reg_miso_i_6        => reg_miso_freq_trim,

        -- Output data/valid
        reg_miso_o          => reg_miso_mux_2
    );

    i_reg_miso_mux_top: entity work.reg_miso_mux6
    port map (
        -- Clock
        reg_clk             => reg_clk,

        -- Input data/valid
        reg_miso_i_1        => reg_miso_mux_1,
        reg_miso_i_2        => reg_miso_mux_2,
        reg_miso_i_3        => reg_miso_drm_if,
        reg_miso_i_4        => reg_miso_dummy,
        reg_miso_i_5        => reg_miso_dummy,
        reg_miso_i_6        => reg_miso_dummy,

        -- Output data/valid
        reg_miso_o          => reg_miso
    );

    i_mercury_clocks: entity work.mercury_clocks
    port map (
        -- Clock Input
        clk_10m_i           => clk_10m,

        -- Register clock and locked signal
        reg_clk_o           => reg_clk,

        -- DDS sync clk buffer
        dds_sync_clk_i      => dds_sync_clk,
        dds_sync_clk_o      => dds_sync_clk_c,
        dds_sync_clk_ce     => synth_ld,            -- Use the synth lock detect input to gate the DDS sync clock

        -- CPU SPI clk buffer
        spi_cpu_clk_i       => spi_cpu_clk,
        spi_cpu_clk_o       => spi_cpu_clk_c,
        spi_cpu_ce          => spi_cpu_ce,

        -- Synth reference clock
        synth_refclk_o      => synth_refclk
     );

end rtl;


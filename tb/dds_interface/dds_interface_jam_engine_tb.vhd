----------------------------------------------------------------------------------
--! @file dds_interface_jam_engine_tb.vhd
--! @brief Module descriptions
--!
--! Further detail
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

use work.mercury_pkg.all;
use work.reg_pkg.all;

library unisim;
use unisim.vcomponents.all;

--! @brief Entity description
--!
--! Further detail
entity dds_interface_jam_engine_tb is
end dds_interface_jam_engine_tb;

architecture tb of dds_interface_jam_engine_tb is
    constant LINE_ADDR_BITS     : natural := 15;

    -- Data Reset
    signal drst                 : std_logic := '0';                 --! Asynchronous data reset (used for synchronisers)

    -- Register Bus
    signal reg_clk              : std_logic;                        --! The register clock
    signal reg_srst             : std_logic;                        --! Register synchronous reset
    signal reg_mosi_ecm         : reg_mosi_type;                    --! Register master-out, slave-in signals, ECM master
    signal reg_miso_ecm_dds     : reg_miso_type;                    --! Register master-in, slave-out signals, ECM master, DDS slave
    signal reg_miso_ecm_jam     : reg_miso_type;                    --! Register master-in, slave-out signals, ECM master, jam engine slave
    signal reg_mosi_drm         : reg_mosi_type;                    --! Register master-out, slave-in signals, DRM master
    signal reg_miso_drm         : reg_miso_type;                    --! Register master-in, slave-out signals, DRM master, jam engine slave

    -- Jamming engine inteface signals
    signal jam_rd_en            : std_logic;                        --! Read jamming line data from FWFT FIFO
    signal jam_data             : std_logic_vector(31 downto 0);    --! Jamming line read data
    signal jam_terminate_line   : std_logic;                        --! Jamming line data ready flag
    signal jam_fifo_empty       : std_logic;                        --! Jamming engine FIFO empty
    signal jam_en_n             : std_logic;                        --! Jamming engine enable (disable manual control)
    signal jam_rf_ctrl          : std_logic_vector(31 downto 0);    --! Jamming Engine RF control word
    signal jam_rf_ctrl_valid    : std_logic;                        --! Jamming Engine RF control word valid

    -- VSWR engine signals
    signal vswr_line_start      : std_logic;                        --! Asserted high for one clock cycle when VSWR test line starts

    -- Blanking signals
    signal jam_blank_out_n      : std_logic;                        --! Jamming blank output
    signal jam_blank_en         : std_logic;                        --! Jamming blank enable
    signal blank_in_n           : std_logic := '1';                 --! Internal blanking input signal

    -- Internal 1PPS signal
    signal int_pps              : std_logic := '0';

    -- Timing Protocol control
    signal tp_sync_en           : std_logic := '0';                 --! Synchronous Timing Protocol enable
    signal dds_restart_prep     : std_logic := '0';                 --! Prepare DDS for line restart (async TP)
    signal dds_restart_exec     : std_logic := '0';                 --! Execute DDS line restart (async TP)

    -- AD9914 inout
    signal dds_d                : std_logic_vector(31 downto 0);    --! DDS data/address/serial pins

    -- AD9914 inputs
    signal dds_ext_pwr_dwn      : std_logic;                        --! DDS power down
    signal dds_reset            : std_logic;                        --! DDS asynchronous reset signal, active high
    signal dds_osk              : std_logic;                        --! DDS On-Off Shift Keying (OSK) output
    signal dds_io_update        : std_logic := '0';                 --! IO Update line
    signal dds_dr_hold          : std_logic;                        --! "Digital ramp hold" signal
    signal dds_dr_ctl           : std_logic;                        --! "Digital ramp control" signal
    signal dds_ps               : std_logic_vector(2 downto 0);     --! DDS profile select
    signal dds_f                : std_logic_vector(3 downto 0);     --! DDS function - selects SPI/parallel interface
    -- AD9914 outputs
    signal dds_dr_over          : std_logic := '0';                 --! "Digital ramp over" signal
    signal dds_sync_clk         : std_logic;                        --! DDS sync clock signal

    signal dds_ref_clk          : std_logic;
    signal dds_ref_clk_n        : std_logic;

    -- Daughter Board ID
    signal dgtr_id              : std_logic_vector(3 downto 0) := "1111"; --! Daughter board ID

    -- Receive test mode enable
    signal rx_test_en           : std_logic := '0';

    -- VSWR engine signals
    signal vswr_line_addr       : std_logic_vector(LINE_ADDR_BITS-1 downto 0);   --! VSWR test line base address
    signal vswr_line_req        : std_logic := '0';                              --! Request VSWR test using line at vswr_line_addr
    signal vswr_line_ack        : std_logic;                                     --! VSWR request being serviced

    -- Testbench signals
    signal data_count           : std_logic_vector(31 downto 0) := (others => '0');
    signal jam_restart          : std_logic := '0';

    constant REG_CLK_PERIOD     : time := 12.5 ns;                    --! Register clock = 80MHz
    constant DDS_REF_CLK_PERIOD : time := 0.3086419753086419753 ns;   --! 3240MHz
    constant SYNC_CLK_PERIOD    : time := 7.4074074074074074074 ns; --! 135MHz (3240MHz / 24)

begin
    reg_clk_proc: process
    begin
        reg_clk <= '0';
        wait for REG_CLK_PERIOD/2;
        reg_clk <= '1';
        wait for REG_CLK_PERIOD/2;
    end process;

    sync_clk_proc: process
    begin
        dds_sync_clk <= '0';
        wait for SYNC_CLK_PERIOD/2;
        dds_sync_clk <= '1';
        wait for SYNC_CLK_PERIOD/2;
    end process;

    ref_clk_proc: process
    begin
        dds_ref_clk <= '0';
        dds_ref_clk_n <= '1';
        wait for DDS_REF_CLK_PERIOD/2;
        dds_ref_clk <= '1';
        dds_ref_clk_n <= '0';
        wait for DDS_REF_CLK_PERIOD/2;
    end process;

    reg_stim_proc: process
    begin
        reg_srst <= '1';
        reg_mosi_ecm.valid <= '0';
        reg_mosi_drm.valid <= '0';

        wait for REG_CLK_PERIOD*10;
        reg_srst <= '0';

        wait for REG_CLK_PERIOD*10;

        -- Bring DDS out of reset
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"00000000";
        reg_mosi_ecm.addr    <= REG_ADDR_DDS_CTRL;
        reg_mosi_ecm.valid   <= '1';
        reg_mosi_ecm.rd_wr_n <= '0';

        -- Write jamming line to memory
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"00000400";
        reg_mosi_ecm.addr    <= REG_JAM_ENG_LINE_BASE;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"12345678";
        reg_mosi_ecm.addr    <= REG_JAM_ENG_LINE_BASE + 1;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"5A5A5A5A";
        reg_mosi_ecm.addr    <= REG_JAM_ENG_LINE_BASE + 2;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"8000FFFF";
        reg_mosi_ecm.addr    <= REG_JAM_ENG_LINE_BASE + 3;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"0000001B";
        reg_mosi_ecm.addr    <= REG_JAM_ENG_LINE_BASE + 4;
        
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"00000400";
        reg_mosi_ecm.addr    <= REG_JAM_ENG_LINE_BASE + 5;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"87654321";
        reg_mosi_ecm.addr    <= REG_JAM_ENG_LINE_BASE + 6;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"A5A5A5A5";
        reg_mosi_ecm.addr    <= REG_JAM_ENG_LINE_BASE + 7;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"FFFF8000";
        reg_mosi_ecm.addr    <= REG_JAM_ENG_LINE_BASE + 8;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"0000001B";
        reg_mosi_ecm.addr    <= REG_JAM_ENG_LINE_BASE + 9;
        
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"00000400";
        reg_mosi_ecm.addr    <= REG_JAM_ENG_LINE_BASE + 10;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"87654321";
        reg_mosi_ecm.addr    <= REG_JAM_ENG_LINE_BASE + 11;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"A5A5A5A5";
        reg_mosi_ecm.addr    <= REG_JAM_ENG_LINE_BASE + 12;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"FFFF8000";
        reg_mosi_ecm.addr    <= REG_JAM_ENG_LINE_BASE + 13;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"00000087";
        reg_mosi_ecm.addr    <= REG_JAM_ENG_LINE_BASE + 14;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"00000000";
        reg_mosi_ecm.addr    <= REG_ENG_1_START_ADDR_MAIN;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"00000004";
        reg_mosi_ecm.addr    <= REG_ENG_1_END_ADDR_MAIN;
        
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"00000005";
        reg_mosi_ecm.addr    <= REG_ENG_1_START_ADDR_SHADOW;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"0000000E";
        reg_mosi_ecm.addr    <= REG_ENG_1_END_ADDR_SHADOW;        

        -- Bring jamming engine out of reset
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"00000000";
        reg_mosi_ecm.addr    <= REG_ENG_1_CONTROL;

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.valid <= '0';

        wait for 10 us;

        -- Switch to shadow registers
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"00000008";
        reg_mosi_ecm.addr    <= REG_ENG_1_CONTROL;
        reg_mosi_ecm.valid   <= '1';

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.valid <= '0';
        
        wait for 900240 ns;
        -- Switch back to main registers
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.data    <= x"00000000";
        reg_mosi_ecm.addr    <= REG_ENG_1_CONTROL;
        reg_mosi_ecm.valid   <= '1';

        wait until rising_edge(reg_clk);
        reg_mosi_ecm.valid <= '0';
        
        wait;
    end process;
    
    restart_stim_proc: process
    begin

        wait for 730531250 ps;
        wait until rising_edge(reg_clk);
        dds_restart_prep <= '1';

        wait for 50 ns;
        wait until rising_edge(reg_clk);
        dds_restart_prep <= '0';
        dds_restart_exec <= '1';

        wait until rising_edge(reg_clk);
        dds_restart_exec <= '0';

        wait for 175.02 us;
        wait until rising_edge(reg_clk);
        dds_restart_prep <= '1';

        wait for 5.18 us;
        wait until rising_edge(reg_clk);
        dds_restart_prep <= '0';
        dds_restart_exec <= '1';

        wait until rising_edge(reg_clk);
        dds_restart_exec <= '0';

        wait for 104 us;
        wait until rising_edge(reg_clk);
        dds_restart_prep <= '1';

        wait for 40 us;
        wait until rising_edge(reg_clk);
        dds_restart_prep <= '0';
        dds_restart_exec <= '1';

        wait until rising_edge(reg_clk);
        dds_restart_exec <= '0';

        -- Wait and execute some invalid cases that dds_interface should tolerate
        wait for 50 us;
        wait until rising_edge(reg_clk);
        dds_restart_prep <= '1';
        dds_restart_exec <= '1';

        wait until rising_edge(reg_clk);
        dds_restart_prep <= '0';
        dds_restart_exec <= '0';

        wait for 50 us;
        wait until rising_edge(reg_clk);
        dds_restart_exec <= '1';

        wait until rising_edge(reg_clk);
        dds_restart_exec <= '0';

        wait for 50 us;
        wait until rising_edge(reg_clk);
        dds_restart_prep <= '1';

        wait until rising_edge(reg_clk);
        dds_restart_prep <= '0';

        wait for 50 us;
        wait until rising_edge(reg_clk);
        dds_restart_exec <= '1';

        wait until rising_edge(reg_clk);
        dds_restart_exec <= '0';

        -- Wait and then pump through repetitive restarts
        while true loop
            wait for 144us;
            wait until rising_edge(reg_clk);
            dds_restart_prep <= '1';

            wait for 21 us;
            wait until rising_edge(reg_clk);
            dds_restart_prep <= '0';
            dds_restart_exec <= '1';

            wait until rising_edge(reg_clk);
            dds_restart_exec <= '0';
        end loop;

        wait;
    end process;

    i_dds_interface: entity work.dds_interface
    generic map (SYNC_CLKS_PER_SEC => 100000)
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi_ecm,
        reg_miso            => reg_miso_ecm_dds,

        -- Jamming engine signals
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
        jam_blank_out_n     => jam_blank_out_n,
        blank_in_n          => blank_in_n,

        -- Internal 1PPS signal
        int_pps_i           => int_pps,

        -- Timing Protocol control
        tp_sync_en          => tp_sync_en,
        dds_restart_prep    => dds_restart_prep,
        dds_restart_exec    => dds_restart_exec,

        -- AD9914 signals
        dds_ext_pwr_dwn     => dds_ext_pwr_dwn,
        dds_reset           => dds_reset,
        dds_d               => dds_d,
        dds_osk             => dds_osk,
        dds_io_update       => dds_io_update,
        dds_dr_over         => dds_dr_over,
        dds_dr_hold         => dds_dr_hold,
        dds_dr_ctl          => dds_dr_ctl,
        dds_sync_clk        => dds_sync_clk,
        dds_ps              => dds_ps,
        dds_f               => dds_f,

        -- Daughter Board ID
        dgtr_id             => dgtr_id
     );

    i_jam_engine: entity work.jam_engine_top
    generic map (LINE_ADDR_BITS => LINE_ADDR_BITS)
    port map (
        -- DDS Clock
        dds_sync_clk        => dds_sync_clk,

        -- Register Clock/Reset
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,

        -- ECM Register Bus
        reg_mosi_ecm        => reg_mosi_ecm,
        reg_miso_ecm        => reg_miso_ecm_jam,

        -- DRM Register Bus
        reg_mosi_drm        => reg_mosi_drm,
        reg_miso_drm        => reg_miso_drm,

        -- Receive test mode enable
        rx_test_en          => rx_test_en,

        -- Jamming engine enable
        jam_en_n            => jam_en_n,

        -- VSWR engine signals
        vswr_line_addr      => vswr_line_addr,
        vswr_line_req       => vswr_line_req,
        vswr_line_ack       => vswr_line_ack,

        -- DDS interface signals
        jam_rd_en          => jam_rd_en,
        jam_data           => jam_data,
        jam_terminate_line => jam_terminate_line,
        jam_fifo_empty     => jam_fifo_empty
     );
end tb;

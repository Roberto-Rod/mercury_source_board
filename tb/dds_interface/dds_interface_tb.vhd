----------------------------------------------------------------------------------
--! @file dds_interface_tb.vhd
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
entity dds_interface_tb is
end dds_interface_tb;

architecture tb of dds_interface_tb is
    -- Data Reset
    signal drst                 : std_logic := '0';                 --! Asynchronous data reset (used for synchronisers)

    -- Register Bus
    signal reg_clk              : std_logic;                        --! The register clock
    signal reg_srst             : std_logic;                        --! Register synchronous reset
    signal reg_mosi             : reg_mosi_type;                    --! Register master-out, slave-in signals
    signal reg_miso             : reg_miso_type;                    --! Register master-in, slave-out signals    
    
    -- Jamming engine inteface signals         
    signal jam_rd_en            : std_logic;                        --! Read jamming line data from FWFT FIFO
    signal jam_data             : std_logic_vector(31 downto 0);    --! Jamming line read data        
    signal jam_terminate_line   : std_logic;                        --! Jamming line data ready flag
    signal jam_fifo_empty       : std_logic;                        --! Jamming engine FIFO empty
    signal jam_en_n             : std_logic := '1';                 --! Jamming engine enable (disable manual control)
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
    
    -- Testbench signals
    signal data_count           : std_logic_vector(31 downto 0) := (others => '0');
    signal jam_restart          : std_logic := '0';
        
    constant REG_CLK_PERIOD     : time := 12.5 ns;                    --! Register clock = 80MHz
    constant DDS_REF_CLK_PERIOD : time := 0.3086419753086419753 ns;   --! 3240MHz
    --constant SYNC_CLK_PERIOD    : time := 7.4074074074074074074 ns; --! 135MHz (3240MHz / 24)
    constant SYNC_CLK_PERIOD    : time := 10 ns; --! 100 MHz

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
    
    tb_proc: process
    begin
        reg_srst <= '1';
        reg_mosi.valid <= '0';     
        
        wait for REG_CLK_PERIOD*10;        
        reg_srst <= '0';
        
        wait for REG_CLK_PERIOD*10;        

        -- Bring DDS out of reset
        wait until rising_edge(reg_clk);
        reg_mosi.data    <= x"00000000";
        reg_mosi.addr    <= REG_ADDR_DDS_CTRL;
        reg_mosi.valid   <= '1';
        reg_mosi.rd_wr_n <= '0';
        
        wait until rising_edge(reg_clk);
        reg_mosi.valid <= '0';   

        wait for REG_CLK_PERIOD*50;
       
        jam_en_n <= '0';
        
        wait for 730 us;        
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
    
    p_terminate: process
    begin
        --wait for 775260 ns;
        wait for 751260 ns;
        wait until rising_edge(dds_sync_clk);
        jam_terminate_line <= '1';
        wait until rising_edge(dds_sync_clk);
        jam_terminate_line <= '0';
        
        --wait for 500 us;
        jam_restart <= '1';
        
        wait;        
    end process;
    
    p_pps: process
    begin
        -- Push out a PPS pulse after a fixed delay
        wait for 20 us;
        int_pps <= '1';
        wait for 12.5 ns;
        int_pps <= '0';
        
        -- Push out another PPS pulse after a fixed delay
        wait for 37 us;
        int_pps <= '1';
        wait for 12.5 ns;
        int_pps <= '0';       
        
        -- Now push out regular PPS pulses every 1 ms
        for i in 1 to 100 loop
            wait for 1 ms - 12.5 ns;
            int_pps <= '1';
            wait for 12.5 ns;
            int_pps <= '0';
            
            if i = 5 then
                wait for 12.5 ns;
            end if;
        end loop;       
        
    end process;
    
    wr_fifo_proc: process   
        variable jam_line : natural := 1;
    begin                
        while true loop            
            wait until rising_edge(dds_sync_clk);
            if reg_srst = '1' then
                jam_line := 1;
                jam_fifo_empty <= '0';
                jam_data  <= x"00003722";           -- Ctrl (Non-VSWR line, restart on blank, blanking line, sequence start)
            else
                if jam_terminate_line = '1' then
                    jam_line := 1;
                    jam_data <= x"00003722";           -- Ctrl (Non-VSWR line, restart on blank, blanking line, sequence start)
                    jam_fifo_empty <= '0';
                else
                    if jam_restart = '1' then
                        jam_fifo_empty <= '0';
                    end if;
                    
                    if jam_rd_en = '1' then
                        case jam_line is
                            when 0 =>
                                jam_line := 1;
                                jam_data <= x"00003722";           -- Ctrl (Non-VSWR line, restart on blank, blanking line, sequence start)
                            when 1 =>
                                jam_line := 2;
                                jam_data <= x"44444444";           -- FTW
                            when 2 =>
                                jam_line := 3;
                                jam_data <= x"55555555";           -- DFTW
                            when 3 =>
                                jam_line := 4;
                                jam_data <= x"66666666";           -- ASF/POW
                            when 4 =>                        
                                jam_line := 5;                                            
                                jam_data <= x"000003E8";           -- Duration (10 us)
                            when 5 =>
                                jam_line := 6;
                                jam_data <= x"80073002";           -- Ctrl (VSWR line, continue on blank)
                            when 6 =>
                                jam_line := 7;
                                jam_data <= x"77777777";           -- FTW
                            when 7 =>
                                jam_line := 8;
                                jam_data <= x"88888888";           -- DFTW
                            when 8 =>
                                jam_line := 9;
                                jam_data <= x"99999999";           -- ASF/POW
                            when 9 =>                                                
                                -- ***************************************************** --
                                -- *** Returning to 0 - only using two jamming lines *** --
                                -- ***************************************************** --
                                jam_line := 0; 
                                jam_data <= x"00005DC0";           -- Duration (240 us)
                            when 10 =>
                                jam_line := 11;
                                jam_data <= x"00003622";           -- Ctrl (Non-VSWR line, restart on blank, blanking line)
                            when 11 =>
                                jam_line := 12;
                                jam_data <= x"AAAAAAAA";           -- FTW
                            when 12 =>
                                jam_line := 13;
                                jam_data <= x"BBBBBBBB";           -- DFTW
                            when 13 =>
                                jam_line := 14;
                                jam_data <= x"CCCCCCCC";           -- ASF/POW
                            when 14 =>                        
                                jam_line := 15;                                            
                                jam_data <= x"000007E9";           -- Duration (15 us)
                            when 15 =>
                                jam_line := 16;
                                jam_data <= x"80073002";           -- Ctrl (VSWR line, continue on blank)
                            when 16 =>
                                jam_line := 17;
                                jam_data <= x"DDDDDDDD";           -- FTW
                            when 17 =>
                                jam_line := 18;
                                jam_data <= x"EEEEEEEE";           -- DFTW
                            when 18 =>
                                jam_line := 19;
                                jam_data <= x"FFFFFFFF";           -- ASF/POW
                            when 19 =>                        
                                jam_line := 0; 
                                jam_data <= x"000002A3";           -- Duration (5 us)
                                
                            when others => 
                                
                        end case;
                    end if;
                end if;
            end if;
        end loop;
        wait;
    end process;
    
    i_dut: entity work.dds_interface
    generic map (
        SYNC_CLKS_PER_SEC   => 100000
    )
    port map (
        -- Register Bus
        reg_clk             => reg_clk,          
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso,
        
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
end tb;

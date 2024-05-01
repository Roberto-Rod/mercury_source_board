----------------------------------------------------------------------------------
--! @file jam_engine_tb.vhd
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

--! @brief TODO: Entity description
--!
--! TODO: Further detail
entity jam_engine_tb is
end jam_engine_tb;

architecture tb of jam_engine_tb is   
    constant LINE_ADDR_BITS     : natural := 15;

    --Inputs
    signal dds_sync_clk         : std_logic := '0';
    signal reg_clk              : std_logic := '0';
    signal reg_srst             : std_logic := '0';
    signal reg_mosi_ecm         : reg_mosi_type;
	signal reg_mosi_drm         : reg_mosi_type;
        
    --Outputs   
    signal reg_miso_ecm         : reg_miso_type;
	signal reg_miso_drm         : reg_miso_type;
        
    -- Receive test mode enable
    signal rx_test_en           : std_logic;                                     --! Receive test mode enable

    -- Jamming engine enable
    signal jam_en_n             : std_logic;                                     --! Jamming engine enable (disable manual control)

    -- VSWR engine signals
    signal vswr_line_addr       : std_logic_vector(LINE_ADDR_BITS-1 downto 0);   --! VSWR test line base address
    signal vswr_line_req        : std_logic;                                     --! Request VSWR test using line at vswr_line_addr
    signal vswr_line_ack        : std_logic;                                     --! VSWR request being serviced

    -- DDS interface signals
    signal jam_rd_en            : std_logic;                                     --! Read jamming line data from FWFT FIFO
    signal jam_data             : std_logic_vector(31 downto 0);                 --! Jamming line read data        
    signal jam_terminate_line   : std_logic;                                     --! Terminate active jamming line     
    signal jam_fifo_empty       : std_logic;                                     --! Jamming engine FIFO empty
    
    -- Clock period definitions
    constant reg_clk_period     : time := 12.5 ns;
    constant sync_clk_period    : time := 7.407407407 ns;

begin

    -- Clock process definitions
    reg_clk_proc: process
    begin
        reg_clk <= '0';
        wait for reg_clk_period/2;
        reg_clk <= '1';
        wait for reg_clk_period/2;
    end process;
    
    rd_clk_proc: process
    begin
        dds_sync_clk <= '0';
        wait for sync_clk_period/2;
        dds_sync_clk <= '1';
        wait for sync_clk_period/2;
    end process;
    
    stim_proc: process
    begin
        reg_mosi_ecm.valid <= '0';
        wait until rising_edge(reg_clk);
        reg_srst <= '1';
        wait until rising_edge(reg_clk);
        reg_srst <= '0';
        
        reg_mosi_ecm.addr <= REG_JAM_ENG_LINE_BASE;
        reg_mosi_ecm.data <= x"00000001";
        reg_mosi_ecm.rd_wr_n <= '0';
        reg_mosi_ecm.valid <= '1';
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.valid <= '0';
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.addr <= REG_JAM_ENG_LINE_BASE + 1;
        reg_mosi_ecm.data <= x"00000002";
        reg_mosi_ecm.rd_wr_n <= '0';
        reg_mosi_ecm.valid <= '1';        
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.addr <= REG_JAM_ENG_LINE_BASE + 2;
        reg_mosi_ecm.data <= x"00000003";
        reg_mosi_ecm.rd_wr_n <= '0';
        reg_mosi_ecm.valid <= '1';     
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.addr <= REG_JAM_ENG_LINE_BASE + 3;
        reg_mosi_ecm.data <= x"00000004";
        reg_mosi_ecm.rd_wr_n <= '0';
        reg_mosi_ecm.valid <= '1';        
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.addr <= REG_JAM_ENG_LINE_BASE + 4;
        reg_mosi_ecm.data <= x"00000005";
        reg_mosi_ecm.rd_wr_n <= '0';
        reg_mosi_ecm.valid <= '1';  

        -- Start zeroizing memory
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.addr <= REG_ENG_1_CONTROL;
        reg_mosi_ecm.data <= x"00000005";
        reg_mosi_ecm.rd_wr_n <= '0';
        reg_mosi_ecm.valid <= '1'; 
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.addr <= REG_ENG_1_CONTROL;
        reg_mosi_ecm.data <= x"00000001";
        reg_mosi_ecm.rd_wr_n <= '0';
        reg_mosi_ecm.valid <= '1';
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.valid <= '0'; 
        
        wait for 500 us;
        
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.addr <= REG_JAM_ENG_LINE_BASE;
        reg_mosi_ecm.data <= x"00000001";
        reg_mosi_ecm.rd_wr_n <= '0';
        reg_mosi_ecm.valid <= '1';
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.valid <= '0';
        
        wait for 100 us;
        
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.addr <= REG_ENG_1_CONTROL;
        reg_mosi_ecm.data <= x"00000005";
        reg_mosi_ecm.rd_wr_n <= '0';
        reg_mosi_ecm.valid <= '1';
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.valid <= '0'; 
        
        -- Wait forever (for now)
        wait;
        
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.addr <= REG_JAM_ENG_LINE_BASE;
        reg_mosi_ecm.data <= x"00000000";
        reg_mosi_ecm.rd_wr_n <= '1';
        reg_mosi_ecm.valid <= '1';
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.addr <= REG_JAM_ENG_LINE_BASE + 1;
        reg_mosi_ecm.data <= x"00000000";
        reg_mosi_ecm.rd_wr_n <= '1';
        reg_mosi_ecm.valid <= '1';        
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.addr <= REG_JAM_ENG_LINE_BASE + 2;
        reg_mosi_ecm.data <= x"00000000";
        reg_mosi_ecm.rd_wr_n <= '1';
        reg_mosi_ecm.valid <= '1';     
        -- Address something else
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.addr <= x"000000";
        reg_mosi_ecm.data <= x"00000000";
        reg_mosi_ecm.rd_wr_n <= '1';
        reg_mosi_ecm.valid <= '1';        
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.addr <= REG_JAM_ENG_LINE_BASE + 3;
        reg_mosi_ecm.data <= x"00000000";
        reg_mosi_ecm.rd_wr_n <= '1';
        reg_mosi_ecm.valid <= '1';        
        wait until rising_edge(reg_clk);        
        reg_mosi_ecm.addr <= REG_ENG_1_START_ADDR_MAIN;
        reg_mosi_ecm.data <= x"00000000";
        reg_mosi_ecm.rd_wr_n <= '0';
        reg_mosi_ecm.valid <= '1';
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.addr <= REG_ENG_1_END_ADDR_MAIN;
        reg_mosi_ecm.data <= x"00000004";        
        reg_mosi_ecm.rd_wr_n <= '0';
        reg_mosi_ecm.valid <= '1';
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.addr <= REG_ENG_1_CONTROL;
        reg_mosi_ecm.data <= x"00000000";
        reg_mosi_ecm.rd_wr_n <= '0';
        reg_mosi_ecm.valid <= '1';        
        wait until rising_edge(reg_clk);
        reg_mosi_ecm.valid <= '0';
        
        wait;
    end process;
    
    -- Instantiate the Unit Under Test (UUT)
    uut: entity work.jam_engine_top
    generic map ( LINE_ADDR_BITS => LINE_ADDR_BITS )
    port map (   
        dds_sync_clk        => dds_sync_clk,
        
        -- Register interface
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi_ecm        => reg_mosi_ecm,
        reg_miso_ecm        => reg_miso_ecm,
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
        jam_rd_en           => jam_rd_en,
        jam_data            => jam_data,
        jam_terminate_line  => jam_terminate_line,
        jam_fifo_empty      => jam_fifo_empty
    );   
end tb;
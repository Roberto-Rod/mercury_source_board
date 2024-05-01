----------------------------------------------------------------------------------
--! @file mercury_clocks.vhd
--! @brief Top level clock generation/routing
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
--! @version See Git logs
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;   

library unisim;
use unisim.vcomponents.all;

--! @brief Entity representing the clock management module
--!
--! This entity includes the register clock PLL and the synth reference clock
--! output DDR2 register (forwarding 10MHz input clock)
entity mercury_clocks is    
    port (                                                   
        clk_10m_i           : in std_logic;         --! 10MHz external clock input
                
        reg_clk_o           : out std_logic;        --! The register clock signal
        
        dds_sync_clk_i      : in std_logic;         --! DDS sync clk input
        dds_sync_clk_o      : out std_logic;        --! Buffered DDS sync clk
        dds_sync_clk_ce     : in std_logic;         --! DDS sync clk enable
        
        spi_cpu_clk_i       : in std_logic;         --! CPU SPI clk input
        spi_cpu_clk_o       : out std_logic;        --! CPU SPI clk output
        spi_cpu_ce          : in std_logic;         --! CPI SPI clk enable
        
        synth_refclk_o      : out std_logic         --! Synth reference clock output
     );
end mercury_clocks;

architecture rtl of mercury_clocks is
    -- Buffered clocks
    signal clk_10m_bufio2           : std_logic;
    signal clk_10m_bufg             : std_logic;
    signal clk_10m_n                : std_logic;
    signal dds_sync_clk_bufio2      : std_logic;
    signal spi_cpu_clk_bufio2       : std_logic;    
begin
    -- ODDR2 primitive used to forward clk_10m to synth_refclk
    i_oddr2_synth_refclk: oddr2
    port map (
        D0 => '0',
        D1 => '1',
        C0 => clk_10m_bufg,
        C1 => clk_10m_n,
        CE => '1',
        Q  => synth_refclk_o
    );     
    
    i_pll_reg_clk: entity work.pll_reg_clk
    port map
    (
        -- Clock in/out ports
        clk_in1            => clk_10m_bufg,
        clk_out1           => reg_clk_o
    );
    
    clk_10m_n <= not clk_10m_bufg;
     
    i_clk_10m_bufio2:        bufio2 port map ( I => clk_10m_i,           DIVCLK => clk_10m_bufio2 );
    i_clk_10m_bufg:          bufg   port map ( I => clk_10m_bufio2,      O      => clk_10m_bufg );
    i_dds_sync_clk_bufio2:   bufio2 generic map ( I_INVERT => true )
                                       port map ( I => dds_sync_clk_i,   DIVCLK => dds_sync_clk_bufio2 );
    i_dds_sync_clk_bufgce:   bufgce port map ( I => dds_sync_clk_bufio2, O      => dds_sync_clk_o,
                                                                         CE     => dds_sync_clk_ce );
    i_spi_clk_bufio2:        bufio2 port map ( I => spi_cpu_clk_i,       DIVCLK => spi_cpu_clk_bufio2 ); 
    i_spi_clk_bufgce:        bufgce port map ( I => spi_cpu_clk_bufio2,  O      => spi_cpu_clk_o,  
                                                                         CE     => spi_cpu_ce );
end rtl;



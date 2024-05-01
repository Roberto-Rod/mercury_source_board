----------------------------------------------------------------------------------
--! @file mercury_clocks_tb.vhd
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

use work.mercury_pkg.all;
use work.reg_pkg.all;

--! @brief Entity description
--!
--! Further detail
entity mercury_clocks_tb is
end mercury_clocks_tb;

architecture tb of mercury_clocks_tb is
    signal clk_10m_i            : std_logic;
    signal reg_clk_o            : std_logic;
    signal dds_sync_clk_i       : std_logic;
    signal dds_sync_clk_o       : std_logic;     
    signal dds_sync_clk_ce      : std_logic := '1';
    signal spi_cpu_clk_i        : std_logic;
    signal spi_cpu_clk_o        : std_logic;
    signal spi_cpu_ce           : std_logic := '1';
    signal synth_refclk_o       : std_logic;

    constant CLK_10M_PERIOD     : time := 100 ns;                   --! 10MHz
    constant SPI_CLK_PERIOD     : time := 33.3333333333 ns;         --! 30MHz    
    constant SYNC_CLK_PERIOD    : time := 6.89655172415 ns;         --! 145MHz (3480MHz / 24)

begin
    clk_10m_proc: process
    begin
        clk_10m_i <= '0';
        wait for CLK_10M_PERIOD/2;
        clk_10m_i <= '1';
        wait for CLK_10M_PERIOD/2;
    end process;
    
    sync_clk_proc: process
    begin
        dds_sync_clk_i <= '0';
        wait for SYNC_CLK_PERIOD/2;
        dds_sync_clk_i <= '1';
        wait for SYNC_CLK_PERIOD/2;
    end process;
    
    spi_clk_proc: process
    begin
        spi_cpu_clk_i <= '0';
        wait for SPI_CLK_PERIOD/2;
        spi_cpu_clk_i <= '1';
        wait for SPI_CLK_PERIOD/2;
    end process;    
    
    uut: entity work.mercury_clocks
    port map(                                                   
        clk_10m_i           => clk_10m_i,

        reg_clk_o           => reg_clk_o,
        
        dds_sync_clk_ce     => dds_sync_clk_ce,
        dds_sync_clk_i      => dds_sync_clk_i,
        dds_sync_clk_o      => dds_sync_clk_o,

        spi_cpu_clk_i       => spi_cpu_clk_i,
        spi_cpu_clk_o       => spi_cpu_clk_o,
        spi_cpu_ce          => spi_cpu_ce,

        synth_refclk_o      => synth_refclk_o
     );
 
end tb;
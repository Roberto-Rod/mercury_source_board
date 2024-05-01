----------------------------------------------------------------------------------
--! @file pwr_mon_spi_master_tb.vhd
--! @brief Testbench for power monitor SPI interface module
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

entity pwr_mon_spi_master_tb is
end pwr_mon_spi_master_tb;

architecture tb of pwr_mon_spi_master_tb is
    -- Register Bus
    signal reg_clk             : std_logic;                         --! The register clock
    signal reg_srst            : std_logic := '1';                  --! Register synchronous reset  

    -- Internal parallel bus
    signal read_req            : std_logic;                         --! Read request flag
    signal adc_data_fwd        : std_logic_vector(11 downto 0);     --! Forward data
    signal adc_data_rev        : std_logic_vector(11 downto 0);     --! Reverse data
    signal adc_data_valid      : std_logic;                         --! ADC data valid flag
    
    -- ADC signals
    signal adc_cs_n            : std_logic;                         --! Active-low chip select to ADC
    signal adc_sclk            : std_logic;                         --! Serial clock to ADC
    signal adc_mosi            : std_logic;                         --! Serial data into ADC
    signal adc_miso            : std_logic := 'X';                  --! Serial data out of ADC
    
    -- Testbench signal
    signal adc_data            : std_logic_vector(31 downto 0) := x"1234abcd";
    
    constant REG_CLK_PERIOD : time := 12.5 ns;
begin
    clk_proc: process
    begin
        reg_clk <= '0';
        wait for REG_CLK_PERIOD/2;
        reg_clk <= '1';
        wait for REG_CLK_PERIOD/2;
    end process;
    
    stim_proc: process
    begin
        wait until rising_edge(reg_clk);
        wait until rising_edge(reg_clk);
        reg_srst <= '0';
        wait;
    end process;
    
    adc_proc: process
    begin
        wait until falling_edge(adc_sclk);
        if adc_cs_n = '0' then
            adc_miso <= adc_data(31);
            adc_data <= adc_data(30 downto 0) & adc_data(31);
        else
            adc_miso <= 'X';
        end if;
    end process;
    
    uut: entity work.pwr_mon_spi_master
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,

        -- Internal parallel bus
        read_req            => read_req,
        adc_data_fwd        => adc_data_fwd,
        adc_data_rev        => adc_data_rev,
        adc_data_valid      => adc_data_valid,
        
        -- ADC signals
        adc_cs_n            => adc_cs_n,
        adc_sclk            => adc_sclk,
        adc_mosi            => adc_mosi,
        adc_miso            => adc_miso
    );
end tb;
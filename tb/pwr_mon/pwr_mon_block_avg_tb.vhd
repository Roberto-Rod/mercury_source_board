----------------------------------------------------------------------------------
--! @file pwr_mon_block_avg_tb.vhd
--! @brief Testbench for pwr_mon_block_avg.vhd
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

entity pwr_mon_block_avg_tb is
end pwr_mon_block_avg_tb;

architecture tb of pwr_mon_block_avg_tb is
    -- Register Bus
    signal reg_clk             : std_logic := '0';
    signal reg_srst            : std_logic := '0'; 

    -- ADC input
    signal adc_in              : std_logic_vector(11 downto 0) := (others => '0');
    signal adc_in_valid        : std_logic := '0';
    signal avg_out             : std_logic_vector(11 downto 0);
    signal avg_out_valid       : std_logic;
    
    constant CLK_PERIOD : time := 12.5 ns;
begin

    clock: process
    begin
        reg_clk <= '0';
        wait for CLK_PERIOD/2;
        reg_clk <= '1';
        wait for CLK_PERIOD/2;
    end process;
    
    stimulus: process
        variable val : integer := 100;
    begin                        
        reg_srst     <= '1';
        wait until rising_edge(reg_clk);
        wait until rising_edge(reg_clk);
        wait until rising_edge(reg_clk);
        wait until rising_edge(reg_clk);
        reg_srst     <= '0';
        wait until rising_edge(reg_clk);
        wait until rising_edge(reg_clk);
                
        for i in 0 to 20000 loop            
            wait for CLK_PERIOD*10;
            wait until rising_edge(reg_clk);
            adc_in       <= std_logic_vector(to_unsigned(val, adc_in'length));            
            adc_in_valid <= '1';
            val := val + 3;
            wait until rising_edge(reg_clk);
            adc_in_valid <= '0';            
        end loop;
        wait;
    end process;
    
    i_pwr_mon_block_avg: entity work.pwr_mon_block_avg
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        
        -- ADC input
        adc_in              => adc_in,
        adc_in_valid        => adc_in_valid,
        avg_out             => avg_out,
        avg_out_valid       => avg_out_valid
    );

end tb;
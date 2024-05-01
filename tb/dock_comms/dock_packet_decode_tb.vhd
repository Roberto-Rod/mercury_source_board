----------------------------------------------------------------------------------
--! @file dock_packet_decode_tb.vhd
--! @brief Dock RS485 communications packet decoder testbench
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

entity dock_packet_decode_tb is
end dock_packet_decode_tb;

architecture tb of dock_packet_decode_tb is
    -- Register Bus
    signal reg_clk             : std_logic;      
    signal reg_srst            : std_logic := '1';      

    -- 32-bit decoded & validated data
    signal dout                 : std_logic_vector(31 downto 0);    --! 32-bit decoded & validated data
    signal dout_valid           : std_logic;                        --! 32-bit data valid
    
    -- 8-bit data from UART
    signal rx_data              : std_logic_vector(7 downto 0);      --! 8-bit data from UART
    signal rx_valid             : std_logic;                         --! UART data valid

    constant CLK_PERIOD        : time := 12.5 ns;
begin
    
    -----------------------------
    -- Generate register clock --
    -----------------------------
    clk_proc: process
    begin
        reg_clk <= '0';
        wait for CLK_PERIOD / 2;
        reg_clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;
    
    stim_proc: process
    begin
        wait for 100 ns;
        wait until rising_edge(reg_clk);
        reg_srst <= '1';
        wait until rising_edge(reg_clk);
        reg_srst <= '0';
        wait for CLK_PERIOD * 10;
        
        -- Push a valid packet in with no delays between rx characters
        -- (as if emptying a FIFO containing a complete packet)
        wait until rising_edge(reg_clk);
        rx_valid <= '1';
        rx_data <= x"00";
        wait until rising_edge(reg_clk);
        rx_data <= x"42";
        wait until rising_edge(reg_clk);
        rx_data <= x"30";
        wait until rising_edge(reg_clk);
        rx_data <= x"30";
        wait until rising_edge(reg_clk);
        rx_data <= x"42";
        wait until rising_edge(reg_clk);
        rx_data <= x"FF";
        wait until rising_edge(reg_clk);
        rx_data <= x"1C";
        wait until rising_edge(reg_clk);
        rx_valid <= '0';        
        
        wait;
    end process;
    
    ---------------------
    -- Unit Under Test --
    ---------------------
    i_dock_packet_decode: entity work.dock_packet_decode
    port map(
        srst        => reg_srst,
        clk         => reg_clk,
        dout        => dout,
        dout_valid  => dout_valid,
        rx_data     => rx_data,
        rx_valid    => rx_valid
    );
end tb;
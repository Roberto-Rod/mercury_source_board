----------------------------------------------------------------------------------
--! @file prbs_gen_tb.vhd
--! @brief Pseudo-random bit sequence generator testbench
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
--! @version See Git logs
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity prbs_gen_tb is
end prbs_gen_tb;

architecture tb of prbs_gen_tb is
    signal clk     : std_logic;                         --! Clock input
    signal srst    : std_logic := '0';	                --! Synchronous reset    
    signal ack     : std_logic := '0';                  --! Ack input - generate next bit in PRBS
    signal prbs    : std_logic_vector(15 downto 0);     --! Pseudo-random output
    
    constant CLK_PERIOD : time := 10 ns;
begin
    clk_proc: process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;
    
    stim_proc: process    
    begin
        wait until rising_edge(clk);
        srst <= '1';
        wait until rising_edge(clk);
        srst <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        ack <= '1';
        wait;
    end process;
    
    i_uut: entity work.prbs_gen
	generic map ( out_bits => 16 )
    port map (
        clk     => clk,
        srst    => srst,
        seed    => (others => '0'),
        ack     => ack,
        prbs    => prbs
    );

end tb;
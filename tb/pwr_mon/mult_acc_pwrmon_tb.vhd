----------------------------------------------------------------------------------
--! @file mult_acc_pwrmon_tb.vhd
--! @brief Testbench for mult_acc_pwrmon.vhd
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
--! @version See Git logs
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

entity mult_acc_pwrmon_tb is
end mult_acc_pwrmon_tb;

architecture tb of mult_acc_pwrmon_tb is
    signal reg_clk          : std_logic                     := '0';
    signal reg_srst         : std_logic                     := '1';
    signal ab_valid         : std_logic                     := '1';
    signal a_port           : std_logic_vector(12 downto 0) := (others => '0');
    signal b_port           : std_logic_vector(19 downto 0) := (others => '0');
    signal s_port           : std_logic_vector(32 downto 0);
    
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
    begin
        wait for CLK_PERIOD*10;
        wait until rising_edge(reg_clk);
        reg_srst <= '0';
        
        wait for CLK_PERIOD*10;
        wait until rising_edge(reg_clk);
        a_port <= std_logic_vector(to_signed(1, a_port'length));
        b_port <= std_logic_vector(to_signed(1, b_port'length));
        
        wait until rising_edge(reg_clk);
        a_port <= (others => '0');
        b_port <= (others => '0');
        
        wait;
    end process;

    i_mult_acc_pwrmon : entity work.mult_acc_pwrmon
    port map (
        clk  => reg_clk,
        ce   => ab_valid,
        sclr => reg_srst,
        a    => a_port,
        b    => b_port,
        s    => s_port
    );
end tb;
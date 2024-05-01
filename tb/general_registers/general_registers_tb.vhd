--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   16:27:27 07/19/2013
-- Design Name:   
-- Module Name:   C:/workspace/fpga/src/mercury/general_registers/general_registers_tb.vhd
-- Project Name:  s6_mercury_source_board
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: general_registers
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;     

use work.mercury_pkg.all;
use work.reg_pkg.all;

entity general_registers_tb is
end general_registers_tb;

architecture tb of general_registers_tb is   

    --Inputs
    signal reg_clk   : std_logic := '0';
    signal reg_srst  : std_logic := '0';
    signal reg_mosi  : reg_mosi_type;            
    signal hw_vers   : std_logic_vector(2 downto 0) := "000";
    signal hw_mod    : std_logic_vector(2 downto 0) := "101";

    --Outputs
    signal reg_miso  : reg_miso_type;
    
    -- External GPIO
    signal ext_gpio  : std_logic_vector(7 downto 0);

    -- Clock period definitions
    constant reg_clk_period : time := 12.5 ns;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: entity work.general_registers 
    port map (
        reg_clk   => reg_clk,
        reg_srst  => reg_srst,
        reg_mosi  => reg_mosi,
        reg_miso  => reg_miso,
        ext_gpio  => ext_gpio,
        hw_vers   => hw_vers,
        hw_mod    => hw_mod 
    );

    -- Clock process definitions
    reg_clk_process : process
    begin
        reg_clk <= '0';
        wait for reg_clk_period/2;
        reg_clk <= '1';
        wait for reg_clk_period/2;
    end process;


    -- Stimulus process
    stim_proc : process
    begin		    
        reg_mosi.valid <= '0';
        
        -- Read version
        wait until rising_edge(reg_clk);
        reg_mosi.addr <= REG_ADDR_VERSION;
        reg_mosi.valid <= '1';  
        reg_mosi.rd_wr_n <= '1';
        wait until rising_edge(reg_clk);
        reg_mosi.valid <= '0'; 
        
        -- Read drawing number
        wait until rising_edge(reg_clk);
        reg_mosi.addr <= REG_ADDR_DWG_NUMBER;
        reg_mosi.valid <= '1';  
        reg_mosi.rd_wr_n <= '1';
        wait until rising_edge(reg_clk);
        reg_mosi.valid <= '0';  

        -- Set all GPIO to outputs
        wait until rising_edge(reg_clk);
        reg_mosi.addr <= REG_ADDR_EXT_GPIO_DIR;
        reg_mosi.data <= (others => '1');
        reg_mosi.valid <= '1';  
        reg_mosi.rd_wr_n <= '0';
        wait until rising_edge(reg_clk);
        reg_mosi.valid <= '0'; 
        
        -- Set all GPIO outputs 7:4 to off and 3:0 to on
        wait until rising_edge(reg_clk);
        reg_mosi.addr <= REG_ADDR_EXT_GPIO_DATA;
        reg_mosi.data <= x"0000000f";
        reg_mosi.valid <= '1';  
        reg_mosi.rd_wr_n <= '0';
        wait until rising_edge(reg_clk);
        reg_mosi.valid <= '0';
        
        -- Set 4 GPIO outputs that are on to different rates
        wait until rising_edge(reg_clk);
        reg_mosi.addr <= REG_ADDR_EXT_GPO_FLASH_RATE;
        reg_mosi.data <= x"000000" & "00011011";
        reg_mosi.valid <= '1';  
        reg_mosi.rd_wr_n <= '0';
        wait until rising_edge(reg_clk);
        reg_mosi.valid <= '0';

        
        wait;
    end process;

end tb;

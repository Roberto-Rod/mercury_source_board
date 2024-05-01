----------------------------------------------------------------------------------
--! @file synth_interface_tb.vhd
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
entity synth_interface_tb is
end synth_interface_tb;

architecture tb of synth_interface_tb is
    -- Register Bus
    -- Inputs
    signal reg_clk             : std_logic;    
    signal reg_srst            : std_logic;    
    signal reg_mosi            : reg_mosi_type;
    -- Outputs
    signal reg_miso            : reg_miso_type;

    -- Synth Signals   
    -- Outputs
    signal synth_sclk          : std_logic;    
    signal synth_data          : std_logic;
    signal synth_le            : std_logic;
    signal synth_ce            : std_logic;        
    signal synth_pdrf_n        : std_logic;    
    -- Inputs
    signal synth_ld            : std_logic := '0';        
    signal synth_muxout        : std_logic := '0';
    
    constant REG_CLK_PERIOD     : time := 12.5 ns;           --! Register clock = 80MHz

begin
    reg_clk_proc: process
    begin
        reg_clk <= '0';
        wait for REG_CLK_PERIOD/2;
        reg_clk <= '1';
        wait for REG_CLK_PERIOD/2;
    end process;
    
    stim_proc: process
    begin
        wait until rising_edge(reg_clk);
        reg_srst <= '1';
        wait until rising_edge(reg_clk);
        reg_srst <= '0';
        wait until rising_edge(reg_clk);
        reg_mosi.valid <= '1';
        reg_mosi.data <= x"f0f0f0f0";
        reg_mosi.addr <= REG_ADDR_SYNTH_REG;
        reg_mosi.rd_wr_n <= '0';
        wait until rising_edge(reg_clk);
        reg_mosi.valid <= '0';
        
        wait for 10 us;
        
        wait until rising_edge(reg_clk);
        reg_mosi.valid <= '1';
        reg_mosi.data <= x"aaaaaaaa";
        reg_mosi.addr <= REG_ADDR_SYNTH_REG;
        reg_mosi.rd_wr_n <= '0';
        wait until rising_edge(reg_clk);
        reg_mosi.valid <= '0';
        
        wait;
    end process;

    uut: entity work.synth_interface
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso,

        -- Synth Signals 
        synth_sclk          => synth_sclk,
        synth_data          => synth_data,
        synth_le            => synth_le,    
        synth_ce            => synth_ce,
        synth_ld            => synth_ld,   
        synth_pdrf_n        => synth_pdrf_n,
        synth_muxout        => synth_muxout
     );

end tb;


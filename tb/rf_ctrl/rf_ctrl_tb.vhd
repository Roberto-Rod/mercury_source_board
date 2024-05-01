----------------------------------------------------------------------------------
--! @file rf_ctrl_tb.vhd
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
entity rf_ctrl_tb is
end rf_ctrl_tb;

architecture tb of rf_ctrl_tb is
    -- Register Bus
    signal reg_clk             : std_logic;                         --! The register clock
    signal reg_srst            : std_logic;                         --! Register synchronous reset
    signal reg_mosi            : reg_mosi_type;                     --! Register master-out, slave-in signals
    signal reg_miso            : reg_miso_type;                    --! Register master-in, slave-out signals
    
    -- RF stage control
    signal rf_att_v            : std_logic_vector(2 downto 1);     --! Source board RF attenuator control bits
    signal rf_sw_v_a           : std_logic_vector(2 downto 1);     --! Source board RF blanking switch control bits
    signal rf_sw_v_b           : std_logic_vector(2 downto 1);     --! Source board RF output switch control bits  
     
    -- Daughter board control
    signal dgtr_rf_sw_ctrl     : std_logic_vector(6 downto 0);     --! Daughter board switch control
    signal dgtr_rf_att_ctrl    : std_logic_vector(8 downto 0);     --! Daughter board attenuator control
    signal dgtr_pwr_en_5v5     : std_logic;                        --! Daughter board 5V5 enable (high)
    signal dgtr_pwr_gd_5v5     : std_logic;                         --! Daughter board 5V5 good (high)
    signal dgtr_id             : std_logic_vector(3 downto 0);      --! Daughter board ID
    
    -- Blanking inputs    
    signal int_blank_n         : std_logic;                         --! Internal blanking input synchronised to reg_clk
        
    -- Jamming engine signals
    signal jam_en_n            : std_logic;                        --! Jamming engine enable (disable manual control)
    signal jam_rf_ctrl         : std_logic_vector(31 downto 0);    --! Jamming Engine RF control word
    signal jam_rf_ctrl_valid   : std_logic;                        --! Jamming Engine RF control word valid
    
    constant REG_CLK_PERIOD    : time := 12.5 ns;
    
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
        reg_srst <= '1';
        wait until rising_edge(reg_clk);
        wait until rising_edge(reg_clk);
        reg_srst         <= '0';
        reg_mosi.addr    <= REG_ADDR_BASE_DBLR_ATT + 1;
        reg_mosi.rd_wr_n <= '1';
        reg_mosi.valid   <= '1';
        wait until rising_edge(reg_clk);        
        reg_mosi.valid <= '0';
        wait;        
        
        wait until rising_edge(reg_clk);
        reg_mosi.addr    <= REG_ADDR_BASE_DBLR_ATT + 1;
        wait until rising_edge(reg_clk);
        reg_mosi.addr    <= REG_ADDR_BASE_DBLR_ATT + 2;
        wait until rising_edge(reg_clk);
        reg_mosi.addr    <= REG_ADDR_BASE_DBLR_ATT + 3;        
        wait until rising_edge(reg_clk);        
        reg_mosi.valid <= '0';
        wait;
    end process;

    uut: entity work.rf_ctrl
    port map(
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso,
        
        -- RF stage control
        rf_att_v            => rf_att_v,
        rf_sw_v_a           => rf_sw_v_a,
        rf_sw_v_b           => rf_sw_v_b,
        
        -- Daughter board control
        dgtr_rf_sw_ctrl     => dgtr_rf_sw_ctrl,
        dgtr_rf_att_ctrl    => dgtr_rf_att_ctrl,
        dgtr_pwr_en_5v5     => dgtr_pwr_en_5v5,
        dgtr_pwr_gd_5v5     => dgtr_pwr_gd_5v5,
        dgtr_id             => dgtr_id,

        -- Blanking inputs
        int_blank_n         => int_blank_n,  
        
        -- Jamming engine signals
        jam_en_n            => jam_en_n,
        jam_rf_ctrl         => jam_rf_ctrl,
        jam_rf_ctrl_valid   => jam_rf_ctrl_valid 
    );

end tb;

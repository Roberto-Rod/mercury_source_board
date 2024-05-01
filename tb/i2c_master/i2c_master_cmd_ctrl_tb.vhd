----------------------------------------------------------------------------------
--! @file i2c_master_cmd_ctrl_tb.vhd
--! @brief I2C master controller
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
 
entity i2c_master_cmd_ctrl_tb is
end i2c_master_cmd_ctrl_tb;
 
architecture tb of i2c_master_cmd_ctrl_tb is 
 
    -- Inputs
    signal reg_clk              : std_logic;                   --! The register clock
    signal reg_srst             : std_logic := '1';            --! Register synchronous reset
    signal reg_mosi             : reg_mosi_type;               --! Register master-out, slave-in signals    
    
    -- Outputs
    signal reg_miso             : reg_miso_type;               --! Register master-in, slave-out signals
    
    signal scl_i                : std_logic := '1';            --! Clock input (used for clock stretching)
    signal scl_o                : std_logic;                   --! Clock output
    signal scl_oen              : std_logic;                   --! Clock output enable, active low
    signal sda_i                : std_logic := '1';            --! Data input
    signal sda_o                : std_logic;                   --! Data output
    signal sda_oen              : std_logic;                   --! Data output enable, active low		    
    
    signal scl                  : std_logic;
    signal sda                  : std_logic;
    
    constant I2C_REGISTER_BASE_ADDRESS     : std_logic_vector(23 downto 0) := x"000000";
    constant I2C_CONTROL_REGISTER_ADDRESS  : std_logic_vector(23 downto 0) := x"000100";
    
    -- Clock period definitions
    constant reg_clk_period : time := 12.5 ns;
 
begin    
    scl <= (not scl_oen and scl_o) or (scl_oen and scl_i);
    sda <= (not sda_oen and sda_o) or (sda_oen and sda_i);
    
    -- Instantiate the Unit Under Test (UUT)
    uut: entity work.i2c_master_cmd_ctrl
    generic map ( 
        REGISTER_BASE_ADDRESS    => I2C_REGISTER_BASE_ADDRESS,
        CONTROL_REGISTER_ADDRESS => I2C_CONTROL_REGISTER_ADDRESS,
        I2C_SLAVE_ADDR           => "0010101"
    )
    port map (
        -- Register Bus
        reg_clk     => reg_clk,      
        reg_srst    => reg_srst,      
        reg_mosi    => reg_mosi,      
        reg_miso    => reg_miso,    
        
        -- I2C Buffer Signals
		scl_i       => scl_i, 
        scl_o       => scl_o,
        scl_oen     => scl_oen,
        sda_i       => sda_i,
        sda_o       => sda_o,
        sda_oen     => sda_oen
    );

   -- Clock process
    clk_process: process
    begin
        reg_clk <= '0';
        wait for reg_clk_period/2;
        reg_clk <= '1';
        wait for reg_clk_period/2;
    end process;
 
    -- Stimulus process
    stim_proc: process
    begin		
        reg_mosi.valid <= '0';          
        wait until rising_edge(reg_clk);
        reg_srst <= '1'; 
        wait until rising_edge(reg_clk);
        reg_srst <= '0';  

        wait until rising_edge(reg_clk);
        reg_mosi.valid <= '1';
        reg_mosi.rd_wr_n <= '0';
        reg_mosi.data <= x"00000000";
        reg_mosi.addr <= x"000000";    -- Core out of reset

        wait until rising_edge(reg_clk);
        reg_mosi.valid <= '0';
        reg_mosi.data  <= (others => '0');

        wait until rising_edge(reg_clk);
        reg_mosi.valid <= '1';
        reg_mosi.rd_wr_n <= '0';
        reg_mosi.data <= x"402b0800";
        reg_mosi.addr <= x"000000";    -- Read 0x15, reg 0x08

        wait until rising_edge(reg_clk);
        reg_mosi.valid <= '0';
        reg_mosi.data  <= (others => '0');

        wait;
    end process;
end;

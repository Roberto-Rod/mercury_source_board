
library ieee;
use ieee.std_logic_1164.all;
      
use work.mercury_pkg.all;
use work.reg_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity i2c_master_top is
    generic (
        REGISTER_BASE_ADDRESS    : std_logic_vector(23 downto 0) := (others => '0');
        CONTROL_REGISTER_ADDRESS : std_logic_vector(23 downto 0) := (others => '0');
        I2C_SLAVE_ADDR           : std_logic_vector(6 downto 0)  := "0010101"
    );
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        reg_mosi            : in reg_mosi_type;                     --! Register master-out, slave-in signals
        reg_miso            : out reg_miso_type;                    --! Register master-in, slave-out signals                
        
        -- I2C I/O Signals
        scl                 : inout std_logic;                      --! Clock input/output (input used for clock stretching)
        sda                 : inout std_logic                       --! Bi-directional data
    );
end entity i2c_master_top;

architecture rtl of i2c_master_top is
    signal scl_i            : std_logic; 
    signal scl_o            : std_logic;
    signal scl_oen          : std_logic;
    signal sda_i            : std_logic; 
    signal sda_o            : std_logic;
    signal sda_oen          : std_logic;

begin

    i_i2c_master_cmd_ctrl: entity work.i2c_master_cmd_ctrl
    generic map( 
        REGISTER_BASE_ADDRESS    => REGISTER_BASE_ADDRESS,
        CONTROL_REGISTER_ADDRESS => CONTROL_REGISTER_ADDRESS,
        I2C_SLAVE_ADDR           => I2C_SLAVE_ADDR          
    )
    port map(
        -- Register Bus
        reg_clk             => reg_clk, 
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso,              
        
        -- I2C Buffer Signals
        scl_i               => scl_i,
        scl_o               => scl_o,
        scl_oen             => scl_oen,
        sda_i               => sda_i,
        sda_o               => sda_o,
        sda_oen             => sda_oen
    );    
    
    -- Bi-directional IO Buffers
    i_scl_iobuf: iobuf port map ( I => scl_o, O => scl_i, T => scl_oen, IO => scl);
    i_sda_iobuf: iobuf port map ( I => sda_o, O => sda_i, T => sda_oen, IO => sda);
end architecture rtl;

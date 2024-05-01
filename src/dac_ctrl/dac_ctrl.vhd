
library ieee;
use ieee.std_logic_1164.all;

use work.mercury_pkg.all;
use work.reg_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity dac_ctrl is
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        reg_mosi            : in reg_mosi_type;                     --! Register master-out, slave-in signals
        reg_miso            : out reg_miso_type;                    --! Register master-in, slave-out signals

        -- Frequency trimming control
        dac_val_i           : in std_logic_vector(11 downto 0);     --! DAC value from frequency trimming module
        dac_val_valid_i     : in std_logic;                         --! DAC value valid

        -- I2C I/O Signals
        scl                 : inout std_logic;                      --! Clock input/output
        sda                 : inout std_logic;                      --! Bi-directional data

        -- Other DAC signals
        ldac_n              : out std_logic                         --! Load DAC input (active low)
    );
end entity dac_ctrl;

architecture rtl of dac_ctrl is
    signal scl_i            : std_logic;
    signal scl_o            : std_logic;
    signal scl_oen          : std_logic;
    signal sda_i            : std_logic;
    signal sda_o            : std_logic;
    signal sda_oen          : std_logic;
begin
    ldac_n <= '0';      -- Keep LDAC low

    i_i2c_dac_cmd_ctrl: entity work.i2c_dac_cmd_ctrl
    generic map(
        REGISTER_BASE_ADDRESS    => REG_ADDR_DAC_BASE,
        CONTROL_REGISTER_ADDRESS => REG_ADDR_DAC_CONTROL,
        I2C_SLAVE_ADDR           => "1100000"
    )
    port map(
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso,
        
        -- Frequency trimming control
        dac_val_i           => dac_val_i,
        dac_val_valid_i     => dac_val_valid_i,

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

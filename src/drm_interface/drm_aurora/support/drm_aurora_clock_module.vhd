----------------------------------------------------------------------------------
--! @file drm_aurora_clock_module.vhd
--! @brief Module providing the clocks associated with the Aurora module
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
--! @version See Git logs
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

----------------------------------------------------------------------------------
--! @brief Module providing the clocks associated with the Aurora module
----------------------------------------------------------------------------------
entity drm_aurora_clock_module is
    generic
    (
        constant MULT         :  integer := 16;
        constant DIVIDE       :  integer := 1;
        constant CLK_PERIOD   :  real    := 16.0;
        constant OUT0_DIVIDE  :  integer := 64;
        constant OUT1_DIVIDE  :  integer := 16;
        constant OUT2_DIVIDE  :  integer := 64;
        constant OUT3_DIVIDE  :  integer := 16

    );
    port (
        mgt_clk        : in std_logic;
        mgt_clk_locked : in std_logic;
        user_clk       : out std_logic;
        sync_clk       : out std_logic;
        pll_locked     : out std_logic
    );
end drm_aurora_clock_module;

architecture rtl of drm_aurora_clock_module is
    ---------------------------
    -- CONSTANT DECLARATIONS --
    ---------------------------
    
    --------------------------------
    -- SIGNAL & TYPE DECLARATIONS --
    --------------------------------
    signal clkfb    : std_logic;
    signal clkout0  : std_logic;
    signal clkout1  : std_logic;
    signal reset_n  : std_logic;
begin
    ------------------------
    -- SIGNAL ASSIGNMENTS --
    ------------------------
    reset_n <= not mgt_clk_locked;
    
    -----------------------------
    -- COMBINATORIAL PROCESSES --
    -----------------------------
    
    --------------------------
    -- SEQUENTIAL PROCESSES --
    --------------------------

    ---------------------------
    -- ENTITY INSTANTIATIONS --
    ---------------------------    

    -- Instantiate a PLL module to divide the reference clock
    i_pll_adv: PLL_ADV
    generic map
    (        
        CLKFBOUT_MULT    =>  MULT,
        DIVCLK_DIVIDE    =>  DIVIDE,
        CLKFBOUT_PHASE   =>  0.0,
        CLKIN1_PERIOD    =>  CLK_PERIOD,
        CLKIN2_PERIOD    =>  10.0,          -- Not used
        CLKOUT0_DIVIDE   =>  OUT0_DIVIDE,
        CLKOUT0_PHASE    =>  0.0,
        CLKOUT1_DIVIDE   =>  OUT1_DIVIDE,
        CLKOUT1_PHASE    =>  0.0,
        CLKOUT2_DIVIDE   =>  OUT2_DIVIDE,
        CLKOUT2_PHASE    =>  0.0,
        CLKOUT3_DIVIDE   =>  OUT3_DIVIDE,
        CLKOUT3_PHASE    =>  0.0,
        SIM_DEVICE       => "SPARTAN6"
    )
    port map
    (
        CLKIN1            => mgt_clk,
        CLKIN2            => '0',
        CLKINSEL          => '1',
        CLKFBIN           => clkfb,
        CLKOUT0           => clkout0,
        CLKOUT1           => clkout1,
        CLKOUT2           => open,
        CLKOUT3           => open,
        CLKOUT4           => open,
        CLKOUT5           => open,
        CLKFBOUT          => clkfb,
        CLKFBDCM          => open,
        CLKOUTDCM0        => open,
        CLKOUTDCM1        => open,
        CLKOUTDCM2        => open,
        CLKOUTDCM3        => open,
        CLKOUTDCM4        => open,
        CLKOUTDCM5        => open,
        DO                => open,
        DRDY              => open,
        DADDR             => "00000",
        DCLK              => '0',
        DEN               => '0',
        DI                => x"0000",
        DWE               => '0',
        REL               => '0',
        LOCKED            => pll_locked,
        RST               => reset_n
    );

    -- The user clock and sync clock are distributed on global clock nets
    i_sync_clk_net: BUFG port map (I => clkout1, O => sync_clk);   
    i_user_clk_net: BUFG port map (I => clkout0, O => user_clk);
end rtl;
--------------------------------------------------------------------------------
--    This file is owned and controlled by Xilinx and must be used solely     --
--    for design, simulation, implementation and creation of design files     --
--    limited to Xilinx devices or technologies. Use with non-Xilinx          --
--    devices or technologies is expressly prohibited and immediately         --
--    terminates your license.                                                --
--                                                                            --
--    XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS" SOLELY    --
--    FOR USE IN DEVELOPING PROGRAMS AND SOLUTIONS FOR XILINX DEVICES.  BY    --
--    PROVIDING THIS DESIGN, CODE, OR INFORMATION AS ONE POSSIBLE             --
--    IMPLEMENTATION OF THIS FEATURE, APPLICATION OR STANDARD, XILINX IS      --
--    MAKING NO REPRESENTATION THAT THIS IMPLEMENTATION IS FREE FROM ANY      --
--    CLAIMS OF INFRINGEMENT, AND YOU ARE RESPONSIBLE FOR OBTAINING ANY       --
--    RIGHTS YOU MAY REQUIRE FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY       --
--    DISCLAIMS ANY WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE   --
--    IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR          --
--    REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF         --
--    INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A   --
--    PARTICULAR PURPOSE.                                                     --
--                                                                            --
--    Xilinx products are not intended for use in life support appliances,    --
--    devices, or systems.  Use in such applications are expressly            --
--    prohibited.                                                             --
--                                                                            --
--    (c) Copyright 1995-2017 Xilinx, Inc.                                    --
--    All rights reserved.                                                    --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- You must compile the wrapper file mult_add_pps_sync.vhd when simulating
-- the core, mult_add_pps_sync. When compiling the wrapper file, be sure to
-- reference the XilinxCoreLib VHDL simulation library. For detailed
-- instructions, please refer to the "CORE Generator Help".

-- The synthesis directives "translate_off/translate_on" specified
-- below are supported by Xilinx, Mentor Graphics and Synplicity
-- synthesis tools. Ensure they are correct for your synthesis tool(s).

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
-- synthesis translate_off
LIBRARY XilinxCoreLib;
-- synthesis translate_on
ENTITY mult_add_pps_sync IS
  PORT (
    clk : IN STD_LOGIC;
    ce : IN STD_LOGIC;
    sclr : IN STD_LOGIC;
    a : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
    b : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    c : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
    subtract : IN STD_LOGIC;
    p : OUT STD_LOGIC_VECTOR(13 DOWNTO 5);
    pcout : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
  );
END mult_add_pps_sync;

ARCHITECTURE mult_add_pps_sync_a OF mult_add_pps_sync IS
-- synthesis translate_off
COMPONENT wrapped_mult_add_pps_sync
  PORT (
    clk : IN STD_LOGIC;
    ce : IN STD_LOGIC;
    sclr : IN STD_LOGIC;
    a : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
    b : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    c : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
    subtract : IN STD_LOGIC;
    p : OUT STD_LOGIC_VECTOR(13 DOWNTO 5);
    pcout : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
  );
END COMPONENT;

-- Configuration specification
  FOR ALL : wrapped_mult_add_pps_sync USE ENTITY XilinxCoreLib.xbip_multadd_v2_0(behavioral)
    GENERIC MAP (
      C_AB_LATENCY => -1,
      C_A_TYPE => 0,
      C_A_WIDTH => 9,
      C_B_TYPE => 1,
      C_B_WIDTH => 5,
      C_CE_OVERRIDES_SCLR => 0,
      C_C_LATENCY => -1,
      C_C_TYPE => 0,
      C_C_WIDTH => 9,
      C_OUT_HIGH => 13,
      C_OUT_LOW => 5,
      C_TEST_CORE => 0,
      C_USE_PCIN => 0,
      C_VERBOSITY => 0,
      C_XDEVICEFAMILY => "spartan6"
    );
-- synthesis translate_on
BEGIN
-- synthesis translate_off
U0 : wrapped_mult_add_pps_sync
  PORT MAP (
    clk => clk,
    ce => ce,
    sclr => sclr,
    a => a,
    b => b,
    c => c,
    subtract => subtract,
    p => p,
    pcout => pcout
  );
-- synthesis translate_on

END mult_add_pps_sync_a;

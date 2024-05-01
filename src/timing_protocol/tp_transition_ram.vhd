----------------------------------------------------------------------------------
--! @file tp_transition_ram.vhd
--! @brief Timing Protocol module
--!
--! Dual-Port RAM with Synchronous Read (Read Through) XST infers Block RAM
--! based on example in https://www.xilinx.com/support/documentation/sw_manuals/xilinx12_2/xst.pdf
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
--! @version See Git logs
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity tp_transition_ram is
    generic (
        ADDR_BITS   : integer := 6;
        DATA_BITS   : integer := 24
    );
    port (
        clk        : in std_logic;
        we         : in std_logic;
        a          : in std_logic_vector(ADDR_BITS-1 downto 0);
        a_valid    : in std_logic;
        dpra       : in std_logic_vector(ADDR_BITS-1 downto 0);
        dpra_valid : in std_logic;
        di         : in std_logic_vector(DATA_BITS-1 downto 0);
        spo        : out std_logic_vector(DATA_BITS-1 downto 0);
        spo_valid  : out std_logic;
        dpo        : out std_logic_vector(DATA_BITS-1 downto 0);
        dpo_valid  : out std_logic
    );
end tp_transition_ram;

architecture rtl of tp_transition_ram is
    type ram_type is array ((2**ADDR_BITS)-1 downto 0) of std_logic_vector (DATA_BITS-1 downto 0);
    signal TP_RAM    : ram_type := (others => (others => '0'));
    signal read_a    : std_logic_vector(ADDR_BITS-1 downto 0);
    signal read_dpra : std_logic_vector(ADDR_BITS-1 downto 0);
    
    attribute ram_style           : string;
    attribute ram_style of TP_RAM : signal is "block";
begin
    ----------------------------------------------------------------------------- 
    --! @brief RAM process - implementes dual-port RAM
    --! 
    --! @param[in] clk  Clock, used on rising edge   
    ----------------------------------------------------------------------------- 
    p_tp_ram: process (clk)
        begin
            if rising_edge(clk) then
                if we = '1' then
                    TP_RAM(conv_integer(a)) <= di;
                end if;
                read_a    <= a;
                read_dpra <= dpra;
        end if;
    end process;
    spo <= TP_RAM(conv_integer(read_a));
    dpo <= TP_RAM(conv_integer(read_dpra));
    
    ----------------------------------------------------------------------------- 
    --! @brief Delay instance generating spo_valid
    ----------------------------------------------------------------------------- 
    i_slv_delay_spo: entity work.slv_delay 
    generic map (
        bits    => 1,
        stages  => 1
    )
    port map (
        clk	    => clk,
        i(0)    => a_valid,
        o(0)    => spo_valid
    );
    
    ----------------------------------------------------------------------------- 
    --! @brief Delay instance generating dpo_valid
    ----------------------------------------------------------------------------- 
    i_slv_delay_dpo: entity work.slv_delay 
    generic map (
        bits    => 1,
        stages  => 1
    )
    port map (
        clk	    => clk,
        i(0)    => dpra_valid,
        o(0)    => dpo_valid
    );
end rtl;
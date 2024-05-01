----------------------------------------------------------------------------------
--! @file prbs_gen.vhd
--! @brief Pseudo-random bit sequence generator
--!
--! Generates a single bit pseudo-random bit sequence. Sets PRBS register to seed
--! when srst is asserted (high).
--!
--! Note: seed must not be set to all 1's, as the implementation uses xnor feedback
--! this creates a stuck state (all 0's is a valid state).
--!
--! Feedback taps: http://www.xilinx.com/support/documentation/application_notes/xapp052.pdf
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
--! @version See Git logs
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity prbs_gen is
	generic (
        out_bits    : natural := 16                     --! Number of bits in output word
	);
    port (
        clk     : in std_logic;                         --! Clock input
        srst    : in std_logic;		                    --! Synchronous reset
        seed    : in std_logic_vector(30 downto 0);     --! PRBS seed
        ack     : in std_logic;		                    --! Ack input - generate next bit in PRBS
        prbs    : out std_logic_vector(out_bits-1 downto 0) --! Pseudo-random output
    );
end prbs_gen;

architecture rtl of prbs_gen is
    signal reg          : std_logic_vector(30 downto 0);
begin

    process (clk) is
    begin
        if rising_edge(clk) then
            if srst = '1' then
                reg <= seed;
            elsif ack = '1' then
                for i in 0 to out_bits-1 loop
                    --reg(out_bits-1-i) <= reg(22-i) xnor reg(17-i);  -- 23-bits
                    --reg(out_bits-1-i) <= reg(24-i) xnor reg(21-i);  -- 25-bits
                    reg(out_bits-1-i) <= reg(30-i) xnor reg(27-i);  -- 31-bits
                end loop;
                for i in out_bits to 30 loop
                    reg(i) <= reg(i-out_bits);
                end loop;               
            end if;
        end if;
    end process;
    
    prbs <= reg(out_bits-1 downto 0);

end rtl;

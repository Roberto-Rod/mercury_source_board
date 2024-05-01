----------------------------------------------------------------------------------
--! @file pwr_mon_moving_avg.vhd
--! @brief Reads power monitor ADC and returns forward/reverse results
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
--! @version See Git logs
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

--! @brief Entity providing moving average filter for use with power monitor ADC
entity pwr_mon_moving_avg is
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        coeff               : in std_logic_vector(18 downto 0);     --! Moving average coefficient (unsigned)
        
        -- ADC input
        adc_in              : in std_logic_vector(11 downto 0);     --! ADC input (12-bit current value)
        adc_in_valid        : in std_logic;                         --! ADC input valid flag
        avg_out             : out std_logic_vector(11 downto 0);    --! Moving average output (12-bit)
        avg_out_valid       : out std_logic
    );
end pwr_mon_moving_avg;

architecture rtl of pwr_mon_moving_avg is    
    signal ab_valid         : std_logic_vector(6 downto 0) := (others => '0');
    
    signal a_port           : std_logic_vector(12 downto 0) := (others => '0');
    signal b_port           : std_logic_vector(19 downto 0) := (others => '0');
    signal s_port           : std_logic_vector(32 downto 0);
begin

    process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            -- Hook up the output
            avg_out <= s_port(30 downto 19);    -- 18 downto 0 = fractional
            
            -- Extend coefficient to 20-bits, MSB=0 so it can be used as signed integer.
            b_port <= '0' & coeff;
            
            if (adc_in_valid = '1') then
                ab_valid <= (others => '1');
                a_port   <= std_logic_vector(signed('0' & adc_in) - signed('0' & s_port(30 downto 19)));
            else 
                ab_valid <= '0' & ab_valid(ab_valid'left downto 1);
                a_port   <= (others => '0');
            end if;
        end if;
    end process;

    i_mult_acc_pwrmon : entity work.mult_acc_pwrmon
    port map (
        clk  => reg_clk,
        ce   => ab_valid(0),
        sclr => reg_srst,
        a    => a_port,
        b    => b_port,
        s    => s_port
    );  

    i_valid_delay : entity work.slv_delay
    generic map (
        bits    => 1,
        stages  => 8
    )
    port map (
        clk     => reg_clk,
        i(0)    => adc_in_valid,
        o(0)    => avg_out_valid
    );
end rtl;





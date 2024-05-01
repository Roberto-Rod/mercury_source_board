----------------------------------------------------------------------------------
--! @file pwr_mon_block_avg.vhd
--! @brief Reads power monitor ADC and returns forward/reverse results
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

--! @brief Entity providing interface to power monitor ADC
--!
--! Reads power monitor ADC forward/reverse input_vals
entity pwr_mon_block_avg is
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        
        -- ADC input
        adc_in              : in std_logic_vector(11 downto 0);     --! ADC input (12-bit current value)
        adc_in_valid        : in std_logic;                         --! ADC input valid flag
        avg_out             : out std_logic_vector(11 downto 0);    --! Moving average output (12-bit)
        avg_out_valid       : out std_logic
    );
end pwr_mon_block_avg;

architecture rtl of pwr_mon_block_avg is
    signal sum             : unsigned(14 downto 0);
    signal input_vals      : std_logic_vector(95 downto 0);
    signal adc_in_valid_r  : std_logic := '0';
begin
    process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                sum             <= (others => '0');
                input_vals      <= (others => '0');
                adc_in_valid_r  <= '0';
                avg_out_valid   <= '0';
            else
                -- Defaults
                avg_out_valid <= '0';
                
                -- ADC valid registered
                adc_in_valid_r  <= adc_in_valid;
                
                if adc_in_valid = '1' then
                    sum        <= sum + unsigned(adc_in);
                    input_vals <= input_vals(83 downto 0) & adc_in;
                elsif adc_in_valid_r = '1' then
                    avg_out_valid <= '1';
                    
                    -- Avergage out = sum / 8
                    if sum(2) = '1' then
                        avg_out <= std_logic_vector(sum(14 downto 3) + 1);
                    else
                        avg_out <= std_logic_vector(sum(14 downto 3));
                    end if;
                    
                    -- Pre-subtract the oldest value from the sum, ready for the next addition
                    sum <= sum - unsigned(input_vals(95 downto 84));                    
                end if;                    
            end if;
            
        end if;
    end process;

end rtl;


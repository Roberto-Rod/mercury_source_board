----------------------------------------------------------------------------------
--! @file dock_packet_decode.vhd
--! @brief Dock RS485 communications packet decoder
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

--! @brief Entity providing packet decoding for the dock RS485 communications
entity dock_packet_decode is
    port (
        srst        : in std_logic;                         --! Synchronous reset
        clk         : in std_logic;                         --! Clock
           
        -- 32-bit decoded & validated data           
        dout        : out std_logic_vector(31 downto 0);    --! 32-bit decoded & validated data
        resp_out    : out std_logic_vector(7 downto 0);     --! 8-bit response code
        dout_valid  : out std_logic;                        --! 32-bit data valid
        
        -- 8-bit data from UART
        rx_data     : in std_logic_vector(7 downto 0);      --! 8-bit data from UART
        rx_valid    : in std_logic                          --! UART data valid
    );
end dock_packet_decode;

architecture rtl of dock_packet_decode is
    signal shift_reg    : std_logic_vector(55 downto 0);
    signal shift_valid  : std_logic;
    
    signal resp_decode  : std_logic_vector (7 downto 0);
    signal cksm_decode  : unsigned (15 downto 0);
    signal decode_valid : std_logic;
    
    signal checksum     : unsigned (15 downto 0);
    signal data_count   : unsigned (3 downto 0);
    signal char_timeout : unsigned (22 downto 0); -- 104.9ms @ 80MHz    
    signal timeout_flag : std_logic;
begin
    
    process(clk)
    begin
        if rising_edge(clk) then
            if srst = '1' then                
                data_count   <= (others => '0');
                shift_valid  <= '0';
                timeout_flag <= '0';
            else
                -- Default shift valid and timeout flag to '0'
                shift_valid <= '0';
                timeout_flag <= '0';
                
                if rx_valid = '1' then
                    -- Receive a character - reset the timeout counter and increment the data counter
                    char_timeout <= (others => '1');
                    data_count   <= data_count + 1;
                    shift_reg    <= shift_reg(47 downto 0) & rx_data;
                    shift_valid  <= '1';
                elsif decode_valid = '0' and char_timeout > 0 then
                    -- Waiting for a character within the timeout period
                    char_timeout <= char_timeout - 1;
                else
                    -- Decoded valid message or reached character timeout - 
                    -- reset the data count & the checksum
                    data_count   <= (others => '0');
                    timeout_flag <= '1';
                end if;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if timeout_flag = '1' then
                decode_valid <= '0';
                checksum     <= (others => '0');
            else
                -- Default decode valid to '0'
                decode_valid <= '0';
                
                if shift_valid = '1' then
                    if data_count < 6 then
                        checksum <= checksum + unsigned(x"00" & shift_reg(7 downto 0));
                    elsif data_count = 7 then                                                
                        dout         <= shift_reg(47 downto 16);
                        resp_out     <= shift_reg(55 downto 48);
                        cksm_decode  <= checksum + unsigned(shift_reg(15 downto 0));
                        decode_valid <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    process(clk)
    begin
        if rising_edge(clk) then
            if srst = '1' then
                dout_valid <= '0';            
            else                
                -- If we've received a full packet and the checksum is good then
                -- assert data out valid for one cycle.                
                
                if decode_valid = '1' and cksm_decode = 0 then
                    dout_valid <= '1';
                else
                    dout_valid <= '0';
                end if;
            end if;
        end if;
    end process;    
    
end rtl;



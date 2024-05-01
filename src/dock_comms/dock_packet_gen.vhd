----------------------------------------------------------------------------------
--! @file dock_packet_gen.vhd
--! @brief Dock RS485 communications packet generator
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

--! @brief Entity providing packet generation for the dock RS485 communications
entity dock_packet_gen is
    port (
        srst        : in std_logic;                         --! Synchronous reset
        clk         : in std_logic;                         --! Clock
                
        addr        : in std_logic_vector(15 downto 0);     --! 16-bit address to send to dock
        din         : in std_logic_vector(31 downto 0);     --! 32-bit data to send to dock
        rd_wr_n     : in std_logic;                         --! Read/nWrite flag
        din_valid   : in std_logic;                         --! data/addr/rd_wr_n valid
        
        tx_data     : out std_logic_vector(7 downto 0);     --! 8-bit data to transmit via UART
        tx_valid    : out std_logic                         --! UART data valid
    );
end dock_packet_gen;

architecture rtl of dock_packet_gen is
    signal shift_reg    : std_logic_vector(55 downto 0);
    signal checksum     : unsigned (15 downto 0);
    signal data_count   : unsigned (3 downto 0);
begin
    
    process(clk)
    begin
        if rising_edge(clk) then
            if srst = '1' then
                checksum   <= (others => '0');
                data_count <= (others => '0');
                tx_valid   <= '0';
            else
                -- Default tx valid to '0'
                tx_valid <= '0';    
                
                if din_valid = '1' then
                    checksum   <= (others => '0');
                    if rd_wr_n = '0' then
                        shift_reg  <= x"00" & addr & din;                           -- command code: 0x00, "write register"
                        data_count <= to_unsigned(11, data_count'length);           -- send 9 bytes (+2 clocks for checksum calculation)
                    else                                                            
                        shift_reg  <= x"01" & addr & din;                           -- command code: 0x01, "read register"
                        data_count <= to_unsigned(7, data_count'length);            -- send 5 bytes (+2 clocks for checksum calculation)
                    end if;
                else                                        
                    shift_reg  <= shift_reg(47 downto 0) & x"00";                   -- left-shift shift register
                    if data_count > 0 then
                        data_count <= data_count - 1;                               -- decrement data count
                    end if;
                    
                    if data_count > to_unsigned(4, data_count'length) then
                        tx_data  <= shift_reg(55 downto 48);                        -- transmit shift register 8 msbs
                        tx_valid <= '1';
                        checksum <= checksum + unsigned(shift_reg(55 downto 48));   -- accumulate checksum
                    elsif data_count > to_unsigned(3, data_count'length) then
                        checksum <= not checksum;                                   -- invert checksum (1's complement)
                    elsif data_count > to_unsigned(2, data_count'length) then
                        checksum <= checksum + to_unsigned(1, checksum'length);     -- add 1 to inverted checksum (2's complement)
                    elsif data_count > 0 then
                        checksum <= checksum(7 downto 0) & x"00";                   -- left-shift checksum
                        tx_data  <= std_logic_vector(checksum(15 downto 8));        -- transmit checksum 8 msbs
                        tx_valid <= '1';
                    end if;
                end if;                
            end if;
        end if;
    end process;
    
end rtl;
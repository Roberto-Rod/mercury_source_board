----------------------------------------------------------------------------------
--! @file pwr_mon_spi_master.vhd
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
--! Reads power monitor ADC forward/reverse values
entity pwr_mon_spi_master is
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        
        -- Internal parallel bus
        read_req            : in std_logic;                         --! Read request flag
        adc_data_fwd        : out std_logic_vector(11 downto 0);    --! Forward data
        adc_data_rev        : out std_logic_vector(11 downto 0);    --! Reverse data
        adc_data_valid      : out std_logic;                        --! ADC data valid flag
        
        -- ADC serial signals
        adc_cs_n            : out std_logic;                        --! Active-low chip select to ADC
        adc_sclk            : out std_logic;                        --! Serial clock to ADC
        adc_mosi            : out std_logic;                        --! Serial data into ADC
        adc_miso            : in std_logic                          --! Serial data out of ADC
    );
end pwr_mon_spi_master;

architecture rtl of pwr_mon_spi_master is
    -- ADC SPI state machine
    type fsm_adc_spi_t is (adc_spi_idle, adc_spi_start, adc_spi_transfer, adc_spi_complete);
    signal fsm_adc_spi          : fsm_adc_spi_t;
    
    -- Shift registers
    signal adc_shift_in         : std_logic_vector(31 downto 0);
    signal adc_shift_out        : std_logic_vector(31 downto 0);
    
    -- Count registers
    signal adc_transfer_count   : unsigned(5 downto 0);
    signal spi_clk_count        : unsigned(3 downto 0);
    
begin
    
    -----------------------------------------------------------------------------
    --! @brief Process which reads ADC SPI data
    --!
    --! Reads serial data out of ADC, reads both channels in one operation
    --! forward and reverse results returned in 32-bit data output.
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge  
    -----------------------------------------------------------------------------  
    adc_rd_wr_proc: process (reg_clk)
    begin
        if rising_edge(reg_clk) then        
            if reg_srst = '1' then
                fsm_adc_spi    <= adc_spi_idle;
                adc_sclk       <= '1';
                adc_cs_n       <= '1';
                adc_data_valid <= '0';
            else
                -- Defaults 
                adc_data_valid <= '0';
                
                case fsm_adc_spi is
                    when adc_spi_idle =>                        
                        adc_sclk <= '1';
                        adc_cs_n <= '1';
                        
                        -- Slow sclk down to reg_clk/16
                        spi_clk_count <= (others => '1');                       
                        
                        -- When we receive read request move to start state
                        if read_req = '1' then
                            fsm_adc_spi <= adc_spi_start;
                        end if;
                    
                    when adc_spi_start =>
                        adc_sclk <= '1';
                        adc_cs_n <= '0';
                        
                        -- Set output to read channel 1 followed by channel 2
                        adc_shift_out <= x"00000800";
                        
                        -- Transfer 32-bits on any read/write transaction
                        adc_transfer_count <= to_unsigned(32, adc_transfer_count'length);
                        
                        -- Move to transfer state
                        fsm_adc_spi <= adc_spi_transfer;
                        
                    when adc_spi_transfer =>
                        -- Slow sclk down to reg_clk/16
                        spi_clk_count <= spi_clk_count - 1;    

                        if spi_clk_count = "1111" then
                            adc_transfer_count <= adc_transfer_count - 1;

                            if adc_transfer_count = 0 then
                                fsm_adc_spi <= adc_spi_complete;
                            else
                                adc_sclk <= '0';
                            end if;                                                    
                            
                            -- Shift 32-bit data into ADC.
                            adc_mosi <= adc_shift_out(31);
                            adc_shift_out <= adc_shift_out(30 downto 0) & '0';
                            
                        elsif spi_clk_count = "0111" then
                            adc_sclk <= '1';
                            
                            -- Shift 32-bit data out of ADC
                            adc_shift_in <= adc_shift_in(30 downto 0) & adc_miso;                                                        
                        end if;
                        
                    when adc_spi_complete =>
                        -- De-assert ADC chip select
                        adc_cs_n       <= '1';  

                        -- Assign the parallel output data
                        adc_data_rev   <= adc_shift_in(27 downto 16);
                        adc_data_fwd   <= adc_shift_in(11 downto 0);
                        adc_data_valid <= '1';
                        
                        -- Move back to idle state
                        fsm_adc_spi    <= adc_spi_idle;
                end case;
            end if;
        end if;
    end process; 

end rtl;
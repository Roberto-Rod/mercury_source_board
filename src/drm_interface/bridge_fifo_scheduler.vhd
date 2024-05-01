----------------------------------------------------------------------------------
--! @file bridge_fifo_scheduler.vhd
--! @brief Schedules data into FIFO, allowing two sources to write data
--!
--! Two sources can write data into the module but neither source may write
--! on two consecutive clock cycles.
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

----------------------------------------------------------------------------------
--! @brief Schedules data into FIFO, allowing two sources to write data
----------------------------------------------------------------------------------
entity bridge_fifo_scheduler is
    generic (
        DATA_WIDTH      : integer := 64                                --! Width of input and output data ports
    );
    port (
        -- Clock and reset
        clk_i           : in std_logic;                                --! Clock input
        srst_i          : in std_logic;                                --! Synchronous reset input, active-high
        
        -- Input data
        data_src_1_i    : in std_logic_vector(DATA_WIDTH-1 downto 0);  --! Data from 1st source
        data_src_2_i    : in std_logic_vector(DATA_WIDTH-1 downto 0);  --! Data from 2nd source
        data_valid_1_i  : in std_logic;                                --! Data from 1st source valid
        data_valid_2_i  : in std_logic;                                --! Data from 2nd source valid
        
        -- Output data
        data_o          : out std_logic_vector(DATA_WIDTH-1 downto 0);  --! Data out
        data_valid_o    : out std_logic                                 --! Data out valid
    );
end bridge_fifo_scheduler;

architecture rtl of bridge_fifo_scheduler is
    --============================--
    --== COMPONENT DECLARATIONS ==--
    --============================--
    
    --===========================--
    --== CONSTANT DECLARATIONS ==--
    --===========================--
    
    --=======================--
    --== TYPE DECLARATIONS ==--
    --=======================--
    
    --=========================--
    --== SIGNAL DECLARATIONS ==--
    --=========================--
    signal data_buffer       : std_logic_vector(DATA_WIDTH-1 downto 0);   -- Holding buffer
    signal data_buffer_valid : std_logic;                                 -- Holding buffer contains valid data
    signal data_buffer_src   : std_logic;                                 -- Source of data in buffer ('0' = src_1, '1' = src_2)
begin
    --========================--
    --== SIGNAL ASSIGNMENTS ==--
    --========================--
    
    --=============================--
    --== COMBINATORIAL PROCESSES ==--
    --=============================--
    
    --==========================--
    --== SEQUENTIAL PROCESSES ==--
    --==========================--
    
    -----------------------------------------------------------------------------
    --! @brief The scheduler
    --!
    --! @param[in] clk_i  Clock, used on rising edge  
    -----------------------------------------------------------------------------
    p_schedule: process (clk_i)
    begin
        if rising_edge(clk_i) then                        
            if srst_i = '1' then
                data_valid_o      <= '0';
                data_buffer_valid <= '0';
            else
                -- Defaults
                data_valid_o      <= '0';
                data_buffer_valid <= '0';
                
                -- Have we got buffered data to output?
                if data_buffer_valid = '1' then
                    data_o       <= data_buffer;
                    data_valid_o <= '1';
                    
                    -- Service other port when outputting buffered data
                    -- Neither port may send data on two consecutive cycles
                    if data_buffer_src = '0' then
                        -- Outputting data from source 1, buffer source 2 if necessary
                        if data_valid_2_i = '1' then
                            data_buffer       <= data_src_2_i;
                            data_buffer_valid <= '1';
                            data_buffer_src   <= '1';
                        end if;
                    else
                        -- Outputting data from source 2, buffer source 1 if necessary
                        if data_valid_1_i = '1' then
                            data_buffer       <= data_src_1_i;
                            data_buffer_valid <= '1';
                            data_buffer_src   <= '0';
                        end if;
                    end if;
                else
                    -- No buffered data, service source 1 first
                    if data_valid_1_i = '1' then
                        data_o       <= data_src_1_i;
                        data_valid_o <= '1';
                        
                        -- Outputting data from source 1, buffer source 2 if necessary
                        if data_valid_2_i = '1' then
                            data_buffer       <= data_src_2_i;
                            data_buffer_valid <= '1';
                            data_buffer_src   <= '1';
                        end if;
                    elsif data_valid_2_i = '1' then
                        data_o       <= data_src_2_i;
                        data_valid_o <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    --===========================--
    --== ENTITY INSTANTIATIONS ==--
    --===========================--

end rtl;

----------------------------------------------------------------------------------
--! @file synth_interface.vhd
--! @brief Module descriptions
--!
--! Further detail
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

use work.mercury_pkg.all;
use work.reg_pkg.all;

library unisim;
use unisim.vcomponents.all;

--! @brief Entity description
--!
--! Further detail
entity synth_interface is
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        reg_mosi            : in reg_mosi_type;                     --! Register master-out, slave-in signals
        reg_miso            : out reg_miso_type;                    --! Register master-in, slave-out signals
        
        -- Synth Signals
        synth_sclk          : out std_logic;                        --! Serial clock into synth
        synth_data          : out std_logic;                        --! Serial data into synth
        synth_le            : out std_logic;                        --! Load Enable. Loads data into register
        synth_ce            : out std_logic;                        --! Chip Enable. Logic low powers down the device
        synth_ld            : in std_logic;                         --! Lock Detect. Logic high indicates PLL lock
        synth_pdrf_n        : out std_logic;                        --! RF Power-Down. Logic low mutes the RF outputs
        synth_muxout        : in std_logic                          --! Multiplexer output from synth        
     );
end synth_interface;

architecture rtl of synth_interface is
    -- DDS SPI state machine
    type fsm_spi_t is (SPI_IDLE, SPI_TRANSFER_SETUP, SPI_TRANSFER_HOLD, SPI_COMPLETE);
    signal fsm_spi              : fsm_spi_t; 
    
    -- Internal control register
    signal synth_ctrl_register  : std_logic_vector(31 downto 0);
        
    -- Internal r/w signals
    signal synth_dout           : std_logic_vector(31 downto 0);
    signal synth_dout_valid     : std_logic;  
    
    -- Shift Registers
    signal shift_out            : std_logic_vector(31 downto 0);
    
    -- Clock counter
    signal clk_count            : std_logic_vector(0 downto 0);
    
    -- Register ready
    signal synth_reg_rdy        : std_logic;
    
    -- Transfer counter
    signal transfer_count       : unsigned(4 downto 0) := (others => '0');
   
begin
    with fsm_spi select synth_reg_rdy <= '1' when SPI_IDLE,
                                         '0' when others;
                                         
    -----------------------------------------------------------------------------
    --! @brief Register read/write process, synchronous to reg_clk.
    --!
    --! Handles control register for this module
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge  
    -----------------------------------------------------------------------------  
    reg_rd_wr_proc: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            -- Defaults
            reg_miso.data <= (others => '0');
            reg_miso.ack     <= '0';
            synth_dout_valid <= '0';
            
            synth_ctrl_register(31) <= synth_reg_rdy;
            synth_ctrl_register(30) <= synth_ld;
            synth_ctrl_register(29) <= synth_muxout;
            
            if reg_srst = '1' then
                -- Synchronous Reset                
                synth_ctrl_register <= x"00000000";
            elsif reg_mosi.valid = '1' then
                if reg_mosi.addr = REG_ADDR_SYNTH_CTRL then
                    -- Read Control Register
                    if reg_mosi.rd_wr_n = '1' then
                        reg_miso.ack  <= '1';
                        reg_miso.data <= synth_ctrl_register;
                    -- Write Control Register
                    else
                        synth_ctrl_register <= reg_mosi.data;
                    end if;
                    
                -- Synth register mapped to FPGA register address. 
                -- Synth internal registers are addressed via the 3 LSBs in the data.
                elsif reg_mosi.addr = REG_ADDR_SYNTH_REG then
                    -- Return 0x0 if register is read as synth has no read interface
                    if reg_mosi.rd_wr_n = '1' then                                                
                        reg_miso.ack <= '1';
                    -- Initiate a synth register write
                    else
                        synth_dout <= reg_mosi.data;
                        synth_dout_valid <= '1';
                    end if;
                end if;
            end if;    
        end if;        
    end process;

    -----------------------------------------------------------------------------
    --! @brief Process which writes synth data
    --!
    --! Writes serial data into synth
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge  
    -----------------------------------------------------------------------------  
    synth_wr_proc: process (reg_clk)
    begin
        if rising_edge(reg_clk) then        
            if reg_srst = '1' then
                fsm_spi <= SPI_IDLE;
                synth_sclk <= '0';
                synth_le <= '1';
            else
                case fsm_spi is
                    when SPI_IDLE =>
                        synth_sclk <= '0';
                        synth_le <= '1';
                        shift_out <= synth_dout;
                        
                        -- Transfer 32-bits on any write transaction
                        transfer_count <= to_unsigned(31, transfer_count'length);
                        
                        if synth_dout_valid = '1' then
                            fsm_spi <= SPI_TRANSFER_SETUP;
                            clk_count <= (others => '1');
                            synth_le <= '0';
                        end if;
                        
                    when SPI_TRANSFER_SETUP =>
                        -- Shift 32-bit data into synth.
                        synth_data <= shift_out(shift_out'high);
                        synth_sclk <= '0';
                        clk_count <= clk_count - 1;
                        
                        if clk_count = 0 then
                            shift_out <= shift_out(shift_out'high-1 downto 0) & '0';
                            fsm_spi <= SPI_TRANSFER_HOLD;
                            clk_count <= (others => '1');
                        end if;
                    
                    when SPI_TRANSFER_HOLD =>
                        synth_sclk <= '1';   
                        clk_count <= clk_count - 1;
                        if clk_count = 0 then
                            transfer_count <= transfer_count - 1;
                            clk_count <= (others => '1');
                            if transfer_count = 0 then
                                fsm_spi <= SPI_COMPLETE;
                            else
                                fsm_spi <= SPI_TRANSFER_SETUP;                                
                            end if;
                        end if;
                    
                    when SPI_COMPLETE =>
                        synth_sclk <= '0';
                        fsm_spi <= SPI_IDLE;

                end case;
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------------------
    --! @brief Process which assigns synth hardware control outputs from control register
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge  
    -----------------------------------------------------------------------------  
    synth_hw_out_proc: process (reg_clk)
    begin
        if rising_edge(reg_clk) then            
            synth_ce <= synth_ctrl_register(0);
            synth_pdrf_n <= synth_ctrl_register(1);
        end if;
    end process;        

end rtl;


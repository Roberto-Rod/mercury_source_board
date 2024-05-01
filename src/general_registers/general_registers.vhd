----------------------------------------------------------------------------------
--! @file general_registers.vhd
--! @brief General register read/write interfaces and storage
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
use work.version_pkg.all;
use work.build_id_pkg.all;

--! @brief Entity providing read/write interfaces and storage for general registers
--!
--! General registers include GPIO control and version registers.
entity general_registers is
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        reg_mosi            : in reg_mosi_type;                     --! Register master-out, slave-in signals
        reg_miso            : out reg_miso_type;                    --! Register master-in, slave-out signals
        
        -- External GPIO
        ext_gpio            : inout std_logic_vector(7 downto 0);
        
        -- Hardware version/mod-level
        hw_vers             : in std_logic_vector(2 downto 0);      --! External hardware version pins
        hw_mod              : in std_logic_vector(2 downto 0)       --! External hardware mod-level pins
    );
end general_registers;

architecture rtl of general_registers is
    signal gpio_reg         : std_logic_vector(7 downto 0) := (others => '0');  --! GPIO data register
    signal gpio_dir         : std_logic_vector(7 downto 0) := (others => '0');  --! GPIO direction register, 0=input, 1=output
    signal gpio_rd_bk       : std_logic_vector(7 downto 0) := (others => '0');  --! GPIO read back register, reads inputs/outputs depending on direction
    signal gpo_flash_rate   : std_logic_vector(15 downto 0) := (others => '0'); --! GPO flash rate register
    
    signal count_flash      : unsigned(23 downto 0) := (others => '0');         --! Flash counter - divides clock to 4Hz
    signal flash_4hz        : std_logic_vector(2 downto 0) := (others => '0');  --! 4Hz counter, LSB=4Hz, MSB=1Hz
begin
    
    -----------------------------------------------------------------------------
    --! @brief Register read/write process, synchronous to reg_clk.
    --!
    --! Handles version & drawing number registers
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge  
    -----------------------------------------------------------------------------  
    reg_rd_wr_proc: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            reg_miso.ack  <= '0';
            reg_miso.data <= (others => '0');
            
            if reg_srst = '1' then
                -- Synchronous Reset
                gpio_reg <= (others => '0');
                gpio_dir <= (others => '0');
            elsif reg_mosi.valid = '1' then
                if reg_mosi.addr = REG_ADDR_EXT_GPIO_DATA then
                    -- External GPIO data register
                    if reg_mosi.rd_wr_n = '1' then
                        reg_miso.ack <= '1';
                        reg_miso.data(7 downto 0) <= gpio_rd_bk;
                    else
                        gpio_reg <= reg_mosi.data(7 downto 0);
                    end if;
                elsif reg_mosi.addr = REG_ADDR_EXT_GPIO_DIR then
                    -- External GPIO direction register
                    if reg_mosi.rd_wr_n = '1' then
                        reg_miso.ack              <= '1';
                        reg_miso.data(7 downto 0) <= gpio_dir;
                    else
                        gpio_dir     <= reg_mosi.data(7 downto 0);
                        reg_miso.ack <= '1';
                    end if;   
                elsif reg_mosi.addr = REG_ADDR_EXT_GPO_FLASH_RATE then
                    -- External GPO flash rate register
                    if reg_mosi.rd_wr_n = '1' then
                        reg_miso.ack <= '1';
                        reg_miso.data(15 downto 0) <= gpo_flash_rate;
                    else
                        gpo_flash_rate <= reg_mosi.data(15 downto 0);
                    end if;                   
                elsif reg_mosi.addr = REG_ADDR_VERSION then
                    -- Version Register
                    if reg_mosi.rd_wr_n = '1' then
                        reg_miso.ack <= '1';
                        reg_miso.data <= FPGA_VERSION_MAJOR & FPGA_VERSION_MINOR & FPGA_VERSION_BUILD;
                    end if;
                    
                elsif reg_mosi.addr = REG_ADDR_DWG_NUMBER then
                    -- Drawing Number Register:
                    -- H/W Vers. (1-byte) | H/W Mod. Level (1-byte) | Drawing Number (2-bytes)
                    if reg_mosi.rd_wr_n = '1' then
                        reg_miso.ack  <= '1';
                        reg_miso.data <= "00000" & hw_vers & 
                                         "00000" & hw_mod & 
                                         FPGA_DWG_NUMBER;
                    end if;
                elsif reg_mosi.addr = REG_ADDR_BUILD_ID_LSBS then
                    -- Build ID (Git SHA) LSBs Register
                    if reg_mosi.rd_wr_n = '1' then
                        reg_miso.ack  <= '1';
                        reg_miso.data <= FPGA_BUILD_ID(31 downto 0);
                    end if;                    
                elsif reg_mosi.addr = REG_ADDR_BUILD_ID_MSBS then
                    -- Build ID (Git SHA) MSBs Register
                    if reg_mosi.rd_wr_n = '1' then
                        reg_miso.ack  <= '1';
                        reg_miso.data <= FPGA_BUILD_ID(63 downto 32);
                    end if;                        
                end if;
            end if;
        end if;
    end process;
    
    gen_io: for i in 0 to 7 generate
        output_proc: process(reg_clk)
        begin
            if rising_edge(reg_clk) then                
                if gpio_dir(i) = '1' then
                    if gpio_reg(i) = '1' then
                        if gpo_flash_rate((i*2)+1 downto i*2) = "00" then
                            ext_gpio(i) <= '1';
                        elsif gpo_flash_rate((i*2)+1 downto i*2) = "01" then
                            ext_gpio(i) <= flash_4hz(2);
                        elsif gpo_flash_rate((i*2)+1 downto i*2) = "10" then
                            ext_gpio(i) <= flash_4hz(1);
                        elsif gpo_flash_rate((i*2)+1 downto i*2) = "11" then
                            ext_gpio(i) <= flash_4hz(0);
                        end if;                            
                    else
                        ext_gpio(i) <= '0';
                    end if;
                    gpio_rd_bk(i) <= gpio_reg(i);
                else
                    ext_gpio(i) <= 'Z';
                    gpio_rd_bk(i) <= ext_gpio(i);
                end if;                            
            end if;
        end process;
    end generate;
    
    flash_proc: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if count_flash = to_unsigned(9999999, 24) then
                count_flash <= (others => '0');
                flash_4hz <= flash_4hz + 1;
            else
                count_flash <= count_flash + 1;
            end if;            
        end if;
    end process;

end rtl;



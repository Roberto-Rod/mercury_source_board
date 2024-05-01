----------------------------------------------------------------------------------
--! @file cpu_spi_slave.vhd
--! @brief Module which interfaces CPU SPI bus to internal register bus.
--!
--! Transfers data between spi_clk domain and reg_clk domain. 
--! Timing designed to interface with an SPI master using CPOL=0, CPHA=1.
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

--! @brief Entity representing the SPI to register bus interface
--!
--! This entity interfaces between the master SPI controller (external to the FPGA)
--! and the internal register bus.
entity cpu_spi_slave is    
    port (                        
        -- Slave SPI Bus
        spi_rst_n           : in  std_logic;        --! Asynchronous reset, resets the SPI interface back to initial state
        spi_clk             : in std_logic;         --! SPI clk, driven by master SPI controller
        spi_ce              : out std_logic;        --! SPI clock enable, active high, driven by this controller
        spi_cs_n            : in std_logic;         --! SPI chip select, active low, driven by master SPI controller
        spi_rdy_rd          : out std_logic;        --! SPI ready to read signal, active high, driven by this controller
        spi_error           : out std_logic;        --! SPI error signal, active high, driven by this controller
        spi_mosi            : in std_logic;         --! SPI master-out, slave-in data
        spi_miso            : out std_logic;        --! SPI master-in, slave-out data
        
        -- Register Bus        
        reg_clk             : in std_logic;         --! The register bus clock
        reg_srst            : out std_logic;        --! Register synchronous reset
        reg_miso            : in reg_miso_type;     --! Register master-in, slave-out signals
        reg_mosi            : out reg_mosi_type     --! Register master-out, slave-in signals
     );
end cpu_spi_slave;

architecture rtl of cpu_spi_slave is
    type fsm_spi_t is (CTRL, ADDR, DATA_H, DATA_L);
    
    signal fsm_spi              : fsm_spi_t := CTRL;
    
    signal srst                 : std_logic := '0';
    signal rst_s                : std_logic_vector(3 downto 0);	 
    
    signal data_in              : std_logic_vector(15 downto 0);
    signal data_in_r            : std_logic_vector(15 downto 0);
    signal data_in_rr           : std_logic_vector(15 downto 0);
    signal data_in_valid        : std_logic;
    signal data_in_valid_r      : std_logic;
    signal data_in_valid_rr     : std_logic;
    signal data_in_valid_rrr    : std_logic;
    signal data_in_valid_rrrr   : std_logic;
    
    signal data_out_hold        : std_logic_vector(31 downto 0);
    signal data_out_shift       : std_logic_vector(30 downto 0);
    
    signal data_read            : std_logic;
    signal data_read_r          : std_logic;
    signal data_read_rr         : std_logic;
    
    signal rd_start             : std_logic;
    signal rd_timeout           : unsigned(23 downto 0);    -- 209.7 ms timeout @ 80 MHz
    
    signal count_din            : unsigned(3 downto 0);
    signal count_dout           : unsigned(4 downto 0);
    
    signal ctrl_byte            : std_logic_vector(7 downto 0);
    
begin
    spi_ce   <= not spi_cs_n;
    srst     <= rst_s(0);
    reg_srst <= srst;    
    
    -- Register the asynchronous reset signal onto the reg clk domain
    process (spi_rst_n, reg_clk)
    begin
        if spi_rst_n = '0' then
            rst_s <= (others => '1');
        elsif rising_edge(reg_clk) then
            -- Shift rst_s right, shift a '0' in to the LHS
            rst_s <= '0' & rst_s(3 downto 1);            
        end if;
    end process; 
    
    -- Use asynchronous reset in SPI clock domain as the clock is not continuous

    -- Data input shift register - shift data into parallel register in SPI clock domain
    process (spi_rst_n, spi_clk)
    begin
        if spi_rst_n = '0' then
            count_din <= (others => '0');
        -- Detect SPI clock falling edges 
        elsif falling_edge(spi_clk) then                     
            -- Shift data into input register
            data_in <= data_in(14 downto 0) & spi_mosi;

            count_din <= count_din + 1;
            if count_din = to_unsigned(15, count_din'length) then
                data_in_valid <= '1';
                count_din <= (others => '0');
            else 
                data_in_valid <= '0';
            end if;
        end if;
    end process;
	
	-- Data output shift register
    -- Clock Domain: spi_clk
    process (spi_rst_n, spi_clk)
    begin
        if spi_rst_n = '0' then
            count_dout <= (others => '0');
        elsif rising_edge(spi_clk) then
        
            count_dout <= count_dout + 1;
            if count_dout = to_unsigned(31, count_dout'length) then
                count_dout <= (others => '0');
            end if;
            
            if count_dout = to_unsigned(0, count_dout'length) then
                data_out_shift <= data_out_hold(30 downto 0);
                spi_miso <= data_out_hold(31);
                data_read <= '1';                
            else 
                data_out_shift <= data_out_shift(29 downto 0) & '0';
                spi_miso <= data_out_shift(30);
                data_read <= '0';
            end if;
           
        end if;
    end process; 

    -- Register the parallel SPI data and valid signal into the reg_clk domain
    process (reg_clk)
    begin   
        if rising_edge(reg_clk) then
            if srst = '1' then
                data_in_valid_r     <= '0';
                data_in_valid_rr    <= '0';
                data_in_valid_rrr   <= '0';
                data_in_valid_rrrr  <= '0';
                data_in_r           <= (others => '0');
                data_in_rr          <= (others => '0');                
                data_read_r         <= '0';
                data_read_rr        <= '0';
            else
                data_in_valid_r     <= data_in_valid;
                data_in_valid_rr    <= data_in_valid_r;
                data_in_valid_rrr   <= data_in_valid_rr;
                data_in_valid_rrrr  <= data_in_valid_rrr;
                data_in_r           <= data_in;
                data_in_rr          <= data_in_r;
                data_read_r         <= data_read;
                data_read_rr        <= data_read_r;
            end if;
        end if;
    end process;
    
    -- Data output holding register
    process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if rd_start = '1' then
                rd_timeout <= (others => '1');
            elsif rd_timeout > 0 then
                rd_timeout <= rd_timeout - 1;
            end if;
            
            if reg_miso.ack = '1' then
                data_out_hold <= reg_miso.data;
                spi_rdy_rd <= '1';
                spi_error <= '0';
                rd_timeout <= (others => '0');
            elsif data_read_rr = '1' then
                spi_rdy_rd <= '0';
                spi_error <= '0';
            elsif rd_timeout = 1 then
                data_out_hold <= x"deadbeef";
                spi_rdy_rd <= '1';
                spi_error <= '1';            
            end if;
        end if;
    end process;   
    
    process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            reg_mosi.valid <= '0';
            rd_start <= '0';
            
            if srst = '1' then
                fsm_spi <= CTRL;
            -- Detect when 16-bit word loaded into parallel register
            elsif data_in_valid_rrrr = '0' and data_in_valid_rrr = '1' then
                case fsm_spi is                                           
                    when CTRL =>
                        fsm_spi <= ADDR;
                        ctrl_byte <= data_in_rr(15 downto 8);
                        -- Assign the register address MSBs
                        reg_mosi.addr(23 downto 16) <= data_in_rr(7 downto 0);
                        
                    when ADDR => 
                        fsm_spi <= DATA_H;
                        
                        -- Assign the register address LSBs
                        reg_mosi.addr(15 downto 0) <= data_in_rr;
                        
                        -- If this is a read operation then issue the request now
                        if ctrl_byte = SPI_CTRL_READ_REG then
                            reg_mosi.valid <= '1';
                            reg_mosi.rd_wr_n <= '1';
                            rd_start <= '1';
                        end if;
                        
                    when DATA_H =>
                        fsm_spi <= DATA_L;
                        -- Assign the register data MSBs
                        reg_mosi.data(31 downto 16) <= data_in_rr;
                        
                    when DATA_L =>
                        fsm_spi <= CTRL;
                        
                        -- Assign the register data LSBs
                        reg_mosi.data(15 downto 0) <= data_in_rr;
                        
                        -- If this is a write operation then issue the request now
                        if ctrl_byte = SPI_CTRL_WRITE_REG then
                            reg_mosi.valid <= '1';
                            reg_mosi.rd_wr_n <= '0';
                        end if;                    
                end case;
            end if;
        end if;
    end process;
        
end rtl;

----------------------------------------------------------------------------------
--! @file pwr_mon_capture.vhd
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

use work.mercury_pkg.all;
use work.reg_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity pwr_mon_capture_tb is
end pwr_mon_capture_tb;

architecture tb of pwr_mon_capture_tb is
    -- Register Bus
    signal reg_clk             : std_logic;                        --! The register clock
    signal reg_srst            : std_logic;                        --! Register synchronous reset
    signal reg_mosi            : reg_mosi_type;                    --! Register master-out, slave-in signals
    signal reg_miso            : reg_miso_type;                    --! Register master-in, slave-out signals    
    
    -- Blanking Control
    signal int_blank_n         : std_logic := '1';                 --! Internal blanking signal
    
    -- Capture request
    signal cap_req             : std_logic := '0';
    
    -- Outputs
    signal fwd_out             : std_logic_vector(11 downto 0);    --! Forward ADC value output (averaged)
    signal rev_out             : std_logic_vector(11 downto 0);    --! Reverse ADC value output (averaged)
    signal out_valid           : std_logic;                        --! Outputs valid flag
    
    -- ADC signals
    signal adc_cs_n            : std_logic;                        --! Active-low chip select to ADC
    signal adc_sclk            : std_logic;                        --! Serial clock to ADC
    signal adc_mosi            : std_logic;                        --! Serial data into ADC
    signal adc_miso            : std_logic := '1';                 --! Serial data out of ADC        

    constant CLK_PERIOD : time := 12.5 ns;
begin

    clock: process
    begin
        reg_clk <= '0';
        wait for CLK_PERIOD/2;
        reg_clk <= '1';
        wait for CLK_PERIOD/2;
    end process;
    
    stimulus: process
    begin                        
        reg_srst     <= '1';
        -- Wait for RF to be validated in moving average mode
        wait for 100 us;
        
        wait until rising_edge(reg_clk);
        wait until rising_edge(reg_clk);
        wait until rising_edge(reg_clk);
        wait until rising_edge(reg_clk);
        reg_srst     <= '0';
        wait until rising_edge(reg_clk);
        wait until rising_edge(reg_clk);
        cap_req      <= '1';
        wait until rising_edge(reg_clk);
        cap_req      <= '0';
        
        wait until out_valid = '1';
        wait until rising_edge(reg_clk);
        reg_mosi.data    <= x"80008000";
        reg_mosi.rd_wr_n <= '0';
        reg_mosi.valid   <= '1';
        reg_mosi.addr    <= REG_ADDR_INT_PA_MAF_COEFF;
        wait until rising_edge(reg_clk);
        reg_mosi.valid   <= '0';
        
        wait for CLK_PERIOD * 1000;        
        
        wait until rising_edge(reg_clk);        
        reg_mosi.data    <= x"00000044";
        reg_mosi.rd_wr_n <= '0';
        reg_mosi.valid   <= '1';
        reg_mosi.addr    <= REG_ADDR_INT_PA_MAF_DELAY;
        wait until rising_edge(reg_clk);
        reg_mosi.valid   <= '0';

        wait for 500 us;
        wait until rising_edge(reg_clk);
        reg_mosi.data    <= x"00000000";
        reg_mosi.rd_wr_n <= '0';
        reg_mosi.valid   <= '1';
        reg_mosi.addr    <= REG_ADDR_INT_PA_MAF_COEFF;
        wait until rising_edge(reg_clk);
        reg_mosi.valid   <= '0';
        
        wait for 10 us;
        wait until rising_edge(reg_clk);
        cap_req      <= '1';
        wait until rising_edge(reg_clk);
        cap_req      <= '0';
        
        wait;
    end process;
    
    i_pwr_mon_capture : entity work.pwr_mon_capture
    generic map (
        MAF_COEFF_ADDRESS    => REG_ADDR_INT_PA_MAF_COEFF,
        MAF_DELAY_ADDRESS    => REG_ADDR_INT_PA_MAF_DELAY
    )
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso,

        -- Blanking Control
        int_blank_n         => int_blank_n,
        
        -- Capture request
        cap_req             => cap_req,
        
        -- Outputs
        fwd_out             => fwd_out,
        rev_out             => rev_out,
        out_valid           => out_valid,
        
        -- ADC signals
        adc_cs_n            => adc_cs_n,
        adc_sclk            => adc_sclk,
        adc_mosi            => adc_mosi,
        adc_miso            => adc_miso
    );
    
end tb;
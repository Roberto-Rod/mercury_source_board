----------------------------------------------------------------------------------
--! @file dock_comms_tb.vhd
--! @brief Dock RS485 communications master testbench
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

entity dock_comms_tb is
end dock_comms_tb;

architecture tb of dock_comms_tb is
    -- Register Bus
    signal reg_clk           : std_logic;      
    signal reg_srst          : std_logic := '1';      
    signal reg_mosi          : reg_mosi_type;  
    signal reg_miso          : reg_miso_type;     
    
    -- VSWR Engine Bus
    signal vswr_mosi         : vswr_mosi_type;
    signal vswr_miso         : vswr_miso_type;
    
    -- Dock RS485 Transceiver Pins
    signal dock_comms_ro     : std_logic := '1';
    signal dock_comms_re_n   : std_logic;
    signal dock_comms_de     : std_logic;
    signal dock_comms_di     : std_logic;
    
    constant CLK_PERIOD      : time := 12.5 ns;
begin
    
    -----------------------------
    -- Generate register clock --
    -----------------------------
    clk_proc: process
    begin
        reg_clk <= '0';
        wait for CLK_PERIOD / 2;
        reg_clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;
    
    stim_proc: process
    begin
        vswr_mosi.vswr_period <= '0';
        vswr_mosi.valid       <= '0';
        
        wait for 100 ns;
        wait until rising_edge(reg_clk);
        reg_srst <= '1';
        wait until rising_edge(reg_clk);
        reg_srst <= '0';
        wait for CLK_PERIOD * 10;
        wait until rising_edge(reg_clk);
        
        -- Send a write packet
        reg_mosi.data    <= x"12345678";
        reg_mosi.addr    <= REG_ADDR_BASE_DOCK + x"0170";
        reg_mosi.rd_wr_n <= '0';
        reg_mosi.valid   <= '1';
        wait until rising_edge(reg_clk);
        reg_mosi.valid   <= '0';
        
        wait for 1 ms;
        wait until rising_edge(reg_clk);
        -- Send a read packet to a bad address
        reg_mosi.addr    <= x"000000";
        reg_mosi.rd_wr_n <= '1';
        reg_mosi.valid   <= '1';
        wait until rising_edge(reg_clk);
        reg_mosi.valid   <= '0';        
        
        wait for 1 ms;
        wait until rising_edge(reg_clk);
        -- Send a read packet
        reg_mosi.addr    <= REG_ADDR_BASE_DOCK + x"0170";
        reg_mosi.rd_wr_n <= '1';
        reg_mosi.valid   <= '1';
        wait until rising_edge(reg_clk);
        reg_mosi.valid   <= '0';
        
        wait for 1 ms;
        -- Send 8 write packets
        for i in 1 to 8 loop
            wait until rising_edge(reg_clk);
            reg_mosi.addr    <= reg_mosi.addr + 1;
            reg_mosi.rd_wr_n <= '0';
            reg_mosi.valid   <= '1';
        end loop;
        
        wait until rising_edge(reg_clk);
        reg_mosi.valid   <= '0';    
        
        wait for 1 ms;
        -- Assert VSWR period
        wait until rising_edge(reg_clk);
        vswr_mosi.vswr_period <= '1';
                
        wait for 650 us;
        -- Make VSWR request
        wait until rising_edge(reg_clk);
        vswr_mosi.addr <= "01";
        vswr_mosi.valid <= '1';
        wait until rising_edge(reg_clk);
        vswr_mosi.valid <= '0';
        
        wait for 350 us;
        -- Make another VSWR request
        wait until rising_edge(reg_clk);
        vswr_mosi.valid <= '1';
        wait until rising_edge(reg_clk);
        vswr_mosi.valid <= '0';
        
        wait for 200 us;
        -- De-assert VSWR period
        wait until rising_edge(reg_clk);
        vswr_mosi.vswr_period <= '0';
        
        wait;
    end process;
    
    ---------------------
    -- Unit Under Test --
    ---------------------
    i_dock_comms: entity work.dock_comms
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso,   
        
        -- VSWR Engine Bus
        vswr_mosi           => vswr_mosi,
        vswr_miso           => vswr_miso,

        -- Dock RS485 Transceiver Pins
        dock_comms_ro     => dock_comms_ro,
        dock_comms_re_n   => dock_comms_re_n,
        dock_comms_de     => dock_comms_de,
        dock_comms_di     => dock_comms_di
    );
end tb;
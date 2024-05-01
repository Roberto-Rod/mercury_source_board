----------------------------------------------------------------------------------
--! @file vswr_engine_tb.vhd
--! @brief VSWR Engine Module Testbench
--!
--! Testbench file for VSWR engine
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

entity vswr_engine_tb is
end vswr_engine_tb;

architecture tb of vswr_engine_tb is
    -- Register Bus
    signal reg_clk             : std_logic;                                   
    signal reg_srst            : std_logic := '1';                                   
    signal reg_mosi            : reg_mosi_type;                               
    signal reg_miso            : reg_miso_type;                               
                
    -- Jamming engine enable signal         
    signal jam_en_n            : std_logic := '1';
    
    -- Blanking input
    signal int_blank_n         : std_logic := '1';

    -- Blanking outputs
    signal blank_out_rev_n     : std_logic;                                   
    signal blank_out_all_n     : std_logic;                                   

    -- VSWR engine signals
    signal vswr_line_addr      : std_logic_vector(14 downto 0); 
    signal vswr_line_req       : std_logic;                                   
    signal vswr_line_ack       : std_logic := '0';                                   
    signal vswr_mosi           : vswr_mosi_type;                              
    signal vswr_miso           : vswr_miso_type;                              
    signal vswr_line_start     : std_logic := '0';

    -- 1PPS signals
    signal int_pps             : std_logic := '0';

    constant REG_CLK_PERIOD     : time := 12.5 ns;
begin
    clk_proc: process
    begin
        reg_clk <= '0';
        wait for REG_CLK_PERIOD/2;
        reg_clk <= '1';
        wait for REG_CLK_PERIOD/2;
    end process;
    
    stim_proc: process
    begin
        wait until rising_edge(reg_clk);
        wait until rising_edge(reg_clk);
        reg_srst <= '0';
        
        -- Setup the registers        
        reg_mosi.addr <= REG_ENG_1_VSWR_CONTROL;
        reg_mosi.data <= x"00000002";
        reg_mosi.valid <= '1';        
        wait until rising_edge(reg_clk);
        reg_mosi.addr <= REG_ENG_1_VSWR_WINDOW_OFFS;
        reg_mosi.data <= x"00000002";
        wait until rising_edge(reg_clk);
        reg_mosi.addr <= REG_ENG_1_VSWR_START_ADDR;
        reg_mosi.data <= x"00000100";
        wait until rising_edge(reg_clk);
        reg_mosi.addr <= REG_ENG_1_VSWR_THRESH_BASE;
        reg_mosi.data <= x"0fff0009";
        wait until rising_edge(reg_clk);
        reg_mosi.addr <= REG_ENG_1_VSWR_THRESH_BASE + 1;
        reg_mosi.data <= x"00ff0800";
        wait until rising_edge(reg_clk);
        reg_mosi.addr <= REG_ADDR_JAM_TO_CVSWR_VALID;
        reg_mosi.data <= x"00000010";
        wait until rising_edge(reg_clk);
        reg_mosi.addr <= REG_ADDR_BLANK_TO_CVSWR_INVALID;
        reg_mosi.data <= x"00000008";
        wait until rising_edge(reg_clk);        
        reg_mosi.valid <= '0';
        wait for 1 ms;
        jam_en_n <= '0';
        wait for REG_CLK_PERIOD*100;
        wait until rising_edge(reg_clk);
        int_pps <= '1';
        wait until rising_edge(reg_clk);
        int_pps <= '0';
        wait for 20 ms;
        int_blank_n <= '0';
        wait for 10 ms;
        int_blank_n <= '1';
        wait for 20 ms;
        jam_en_n <= '1';
        wait for 1 ms;
        jam_en_n <= '0';
        wait;
    end process;
    
    ack_start_proc: process
    begin
        while true loop
            wait until rising_edge(reg_clk);
            if vswr_line_req = '1' then                
                wait until rising_edge(reg_clk);
                vswr_line_ack <= '1';
                wait until rising_edge(reg_clk);
                vswr_line_ack <= '0';
                wait for 10 us;
                wait until rising_edge(reg_clk);
                vswr_line_start <= '1';
                wait until rising_edge(reg_clk);
                vswr_line_start <= '0';
            end if;
        end loop;
    end process;
    
    vswr_data_proc: process
    begin
        wait until rising_edge(reg_clk);
        if vswr_mosi.valid = '1' then
            vswr_miso.fwd <= std_logic_vector(to_unsigned(1000, 12));
            vswr_miso.rev <= std_logic_vector(to_unsigned(990, 12));
            vswr_miso.valid <= '1';
        else
            vswr_miso.fwd <= (others => '0');
            vswr_miso.rev <= (others => '0');
            vswr_miso.valid <= '0';
        end if;
    end process;
    
    uut: entity work.vswr_engine
    generic map(LINE_ADDR_BITS => 15)
    port map(
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso,
                    
        -- Jamming engine enable signal         
        jam_en_n            => jam_en_n,
        
        -- Blanking input
        int_blank_n         => int_blank_n,
        
        -- Blanking output  
        blank_out_rev_n     => blank_out_rev_n,
        blank_out_all_n     => blank_out_all_n,
            
        -- VSWR engine signals
        vswr_line_addr      => vswr_line_addr,
        vswr_line_req       => vswr_line_req,
        vswr_line_ack       => vswr_line_ack,
        vswr_mosi           => vswr_mosi,
        vswr_miso           => vswr_miso,
        vswr_line_start     => vswr_line_start,
        
        -- 1PPS signals
        int_pps             => int_pps
    );
end tb;
----------------------------------------------------------------------------------
--! @file rf_ctrl.vhd
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
entity rf_ctrl is
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        reg_mosi            : in reg_mosi_type;                     --! Register master-out, slave-in signals
        reg_miso            : out reg_miso_type;                    --! Register master-in, slave-out signals
        
        -- RF stage control
        rf_att_v            : out std_logic_vector(2 downto 1);     --! Source board RF attenuator control bits
        rf_sw_v_a           : out std_logic_vector(2 downto 1);     --! Source board RF blanking switch control bits
        rf_sw_v_b           : out std_logic_vector(2 downto 1);     --! Source board RF output switch control bits  
        
        -- Daughter board control
        dgtr_rf_sw_ctrl     : out std_logic_vector(6 downto 0);     --! Daughter board switch control
        dgtr_rf_att_ctrl    : out std_logic_vector(8 downto 0);     --! Daughter board attenuator control
        dgtr_pwr_en_5v5     : out std_logic;                        --! Daughter board 5V5 enable (high)
        dgtr_pwr_gd_5v5     : in std_logic;                         --! Daughter board 5V5 good (high)
        dgtr_id             : in std_logic_vector(3 downto 0);      --! Daughter board ID

        -- Blanking input
        int_blank_n         : in std_logic;                         --! Internal blanking input synchronised to reg_clk
        
        -- Jamming engine signals
        jam_en_n            : in std_logic;                        --! Jamming engine enable (disable manual control)
        jam_rf_ctrl         : in std_logic_vector(31 downto 0);    --! Jamming Engine RF control word
        jam_rf_ctrl_valid   : in std_logic                         --! Jamming Engine RF control word valid
     );
end rf_ctrl;

architecture rtl of rf_ctrl is  
    signal ctrl_reg             : std_logic_vector(31 downto 0);
    signal reg_mux              : std_logic_vector(31 downto 0);
    signal src_port_sel         : std_logic;
    signal src_blank            : std_logic;                        -- Control register bit
    signal src_blank_n          : std_logic;                        -- Internal control signal
    
    -- Doubler board signals        
    signal dblr_att_1           : std_logic_vector(3 downto 0);     --! Doubler board attenuator 1
    signal dblr_att_2           : std_logic_vector(4 downto 0);     --! Doubler board attenuator 2
    signal dblr_path            : std_logic_vector(2 downto 0);     --! Doubler board path    
    signal dblr_port_sel        : std_logic;                        --! Doubler board port select
    
    -- Daughter status register
    signal dgtr_status_reg      : std_logic_vector(31 downto 0);
    signal dgtr_pwr_en_5v5_reg  : std_logic;
    
    -- RF switch control words for different board types
    signal mbdb_rf_sw_ctrl      : std_logic_vector(5 downto 0);     --! Mid-Band Doubler Board
    signal hbdb_rf_sw_ctrl      : std_logic_vector(5 downto 0);     --! High-Band Doubler Board
    
    -- Block Memory signals
    signal blk_mem_wea          : std_logic;
    signal blk_mem_addra        : std_logic_vector(7 downto 0);
    signal blk_mem_dina         : std_logic_vector(8 downto 0);
    signal blk_mem_douta        : std_logic_vector(8 downto 0);
    signal blk_mem_addrb        : std_logic_vector(7 downto 0);
    signal blk_mem_doutb        : std_logic_vector(8 downto 0);
    signal blk_mem_doutb_dly    : std_logic_vector(8 downto 0);
    signal blk_mem_rda          : std_logic;
    signal blk_mem_douta_valid  : std_logic;
    
    -- Register signals    
    signal reg_miso_regs        : reg_miso_type;     
    signal reg_miso_blk_mem     : reg_miso_type;     
    signal reg_miso_dummy       : reg_miso_type;     
    
begin
    -- Assign outputs    
    dgtr_pwr_en_5v5 <= dgtr_pwr_en_5v5_reg;   
    
    -- Mid-Band Doubler Board Paths
    with dblr_path select mbdb_rf_sw_ctrl <= "000000" when "000",   -- Path 1 (bypass)
                                             "100001" when "001",   -- Path 2 (1490-1880 MHz)
                                             "010011" when "010",   -- Path 3 (1850-2250 MHz)
                                             "010101" when "011",   -- Path 4 (2250-2500 MHz)
                                             "000111" when "100",   -- Path 5 (2500-2700 MHz)
                                             "001001" when "101",   -- Path 6 (2700-3000 MHz)
                                             "000000" when others;  -- Default case (bypass)

    -- High-Band Doubler Board Paths
    with dblr_path select hbdb_rf_sw_ctrl <= "100000" when "000",   -- Path 0 (1250-2500 MHz)
                                             "000100" when "001",   -- Path 1 (2500-3200 MHz)
                                             "001011" when "010",   -- Path 2 (3200-4800 MHz)
                                             "001101" when "011",   -- Path 3 (4800-6000 MHz)
                                             "100000" when others;  -- Default case (bypass)
                                             
    -- Select RF Switch Control based on daughter board type
    with dgtr_id select dgtr_rf_sw_ctrl(5 downto 0) <= mbdb_rf_sw_ctrl when "0000",
                                                       hbdb_rf_sw_ctrl when "0001",
                                                       "000000"        when others;
    
    -- Doubler board port select
    dgtr_rf_sw_ctrl(6) <= dblr_port_sel;
    
    dgtr_rf_att_ctrl(8 downto 5) <= dblr_att_1; -- Digital Attenuator 1: 3dB step, 45dB range
    dgtr_rf_att_ctrl(4 downto 0) <= dblr_att_2; -- Digital Attenuator 2: 0.25dB step, 7.75dB range
    
    rf_sw_v_a(1) <= not src_blank_n;
    rf_sw_v_a(2) <= src_blank_n;
    
    rf_sw_v_b(1) <= not src_port_sel;
    rf_sw_v_b(2) <= src_port_sel;
    
    -- Assign status register
    dgtr_status_reg <= dgtr_id & dgtr_pwr_gd_5v5 & "000" &
                       x"0000" &                       
                       "0000000" & dgtr_pwr_en_5v5_reg;
    
    -----------------------------------------------------------------------------
    --! @brief Register read/write process, synchronous to reg_clk.
    --!
    --! Handles rf control register
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge  
    -----------------------------------------------------------------------------  
    reg_rd_wr_proc: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            -- Defaults
            reg_miso_regs.ack   <= '0';
            reg_miso_regs.data  <= (others => '0');
            blk_mem_rda         <= '0';
            blk_mem_wea         <= '0';
            
            -- Doubler attenuator memory
            blk_mem_addra  <= reg_mosi.addr(7 downto 0);
            blk_mem_dina   <= reg_mosi.data(8 downto 0);
            
            if reg_srst = '1' then
                -- Synchronous Reset
                ctrl_reg <= (others => '0');
            elsif reg_mosi.valid = '1' then
                if reg_mosi.addr = REG_ADDR_RF_CTRL then
                    -- RF control register
                    if reg_mosi.rd_wr_n = '1' then
                        reg_miso_regs.ack  <= '1';
                        reg_miso_regs.data <= ctrl_reg;
                    else
                        ctrl_reg <= reg_mosi.data ;
                    end if;
                elsif reg_mosi.addr = REG_ADDR_DGTR_CTRL then
                    -- Daughter control/status register
                    if reg_mosi.rd_wr_n = '1' then
                        reg_miso_regs.ack  <= '1';
                        reg_miso_regs.data <= dgtr_status_reg;
                    else
                        dgtr_pwr_en_5v5_reg <= reg_mosi.data(0);
                    end if;
                elsif reg_mosi.addr(23 downto 8) = REG_ADDR_BASE_DBLR_ATT(23 downto 8) then
                    -- Doubler attenuator memory
                    blk_mem_wea <= not reg_mosi.rd_wr_n;
                    blk_mem_rda <= reg_mosi.rd_wr_n;
                end if;
            end if;
        end if;
    end process;
        
    -- Assign the RF control outputs either from the register (manual mode) or the 
    -- jamming engine input (jamming mode)    
    reg_mux_proc: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if jam_en_n = '1' then
                reg_mux <= ctrl_reg;
            elsif jam_rf_ctrl_valid = '1' then
                reg_mux <= jam_rf_ctrl;
            end if;
        end if;
    end process;

    -- Assign the source board blanking outputs either from the register (manual mode) 
    -- or the global internal blanking signal (jamming mode)    
    src_blank_proc: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if jam_en_n = '1' then
                src_blank_n <= not src_blank;
            else
                src_blank_n <= int_blank_n;
            end if;
        end if;
    end process;    
    
    -- Assign the RF control outputs either from the register (manual mode) or the 
    -- jamming engine input (jamming mode)
    reg_output_proc: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            src_port_sel    <= reg_mux(0);
            dblr_port_sel   <= reg_mux(1);
            -- 3 downto 2 reserved
            dblr_path       <= reg_mux(6 downto 4);
            -- 11 downto 7 reserved
            src_blank       <= reg_mux(9);
            rf_att_v        <= reg_mux(13 downto 12);   
            -- 15 downto 14 reserved            
            blk_mem_addrb   <= reg_mux(23 downto 16);
            -- 29 downto 24 reserved
            -- 31, 30 not used in this module (used in jamming engine)
            
            -- Assign the doubler attenuator values
            dblr_att_1      <= blk_mem_doutb_dly(8 downto 5);
            dblr_att_2      <= blk_mem_doutb_dly(4 downto 0);
        end if;
    end process;   
    
    blk_mem_douta_proc: process(reg_clk)
    begin
        if rising_edge(reg_clk) then            
            -- Default
            reg_miso_blk_mem.data <= (others => '0');
            
            if blk_mem_douta_valid = '1' then
                reg_miso_blk_mem.data(8 downto 0) <= blk_mem_douta;
                reg_miso_blk_mem.ack <= '1';
            else                
                reg_miso_blk_mem.ack <= '0';
            end if;
        end if;
    end process;

    -- Register mux assignments
    reg_miso_dummy.data <= (others => '0');        
    reg_miso_dummy.ack  <= '0';   

    i_reg_miso_mux: entity work.reg_miso_mux6
    port map (                                                  
        -- Clock 
        reg_clk             => reg_clk,
        
        -- Input data/valid
        reg_miso_i_1        => reg_miso_regs,
        reg_miso_i_2        => reg_miso_blk_mem,
        reg_miso_i_3        => reg_miso_dummy,
        reg_miso_i_4        => reg_miso_dummy,
        reg_miso_i_5        => reg_miso_dummy,
        reg_miso_i_6        => reg_miso_dummy,
        
        -- Output data/valid
        reg_miso_o          => reg_miso
    );    
    
    i_blk_mem_dblr_att: entity work.blk_mem_dblr_att
    port map (
        clka    => reg_clk,
        wea(0)  => blk_mem_wea,
        addra   => blk_mem_addra,
        dina    => blk_mem_dina,
        douta   => blk_mem_douta,
        clkb    => reg_clk,
        web(0)  => '0',
        addrb   => blk_mem_addrb,
        dinb    => (others => '0'),
        doutb   => blk_mem_doutb
    );
    
    i_blk_mem_rda_dly: entity work.slv_delay
    generic map ( bits => 1, stages => 2 )
    port map (
        clk  => reg_clk,
        i(0) => blk_mem_rda,
        o(0) => blk_mem_douta_valid
    );
    
    -- Doubler attenuator delay - 3 clock cycles. This is to allow the start-of-line
    -- muting to take effect before the attenuator control lines are adjusted.
    i_blk_mem_doutb_dly: entity work.slv_delay
    generic map ( bits => 9, stages => 3 )
    port map (
        clk  => reg_clk,
        i    => blk_mem_doutb,
        o    => blk_mem_doutb_dly
    );
end rtl;

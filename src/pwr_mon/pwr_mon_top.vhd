----------------------------------------------------------------------------------
--! @file pwr_mon_top.vhd
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

use work.mercury_pkg.all;
use work.reg_pkg.all;

--! @brief Entity providing interface to power monitor ADC
--!
--! Reads power monitor ADC forward/reverse values
entity pwr_mon_top is
    generic (
        REGISTER_ADDRESS    : std_logic_vector(23 downto 0) := (others => '0');
        MAF_COEFF_ADDRESS   : std_logic_vector(23 downto 0) := (others => '0');
        MAF_DELAY_ADDRESS   : std_logic_vector(23 downto 0) := (others => '0');
        VSWR_ADDRESS        : std_logic_vector(1 downto 0)  := (others => '0')
    );
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        reg_mosi            : in reg_mosi_type;                     --! Register master-out, slave-in signals
        reg_miso            : out reg_miso_type;                    --! Register master-in, slave-out signals
        
        -- Blanking Control
        int_blank_n         : in std_logic;                         --! Internal blanking signal

        -- VSWR Engine Bus
        vswr_mosi           : in vswr_mosi_type;                    --! VSWR engine master-out, slave-in signals
        vswr_miso           : out vswr_miso_type;                   --! VSWR engine master-in, slave-out signals

        -- ADC signals
        adc_cs_n            : out std_logic;                        --! Active-low chip select to ADC
        adc_sclk            : out std_logic;                        --! Serial clock to ADC
        adc_mosi            : out std_logic;                        --! Serial data into ADC
        adc_miso            : in std_logic                          --! Serial data out of ADC
    );
end pwr_mon_top;

architecture rtl of pwr_mon_top is
    -- Finite State Machine
    type fsm_pwr_mon_t is (IDLE, REG_READ, VSWR_READ);
    signal fsm_pwr_mon : fsm_pwr_mon_t := IDLE;

    -- Capture request
    signal cap_req              : std_logic;

    -- ADC parallel data
    signal avg_data_fwd         : std_logic_vector(11 downto 0);
    signal avg_data_rev         : std_logic_vector(11 downto 0);
    signal avg_data_valid       : std_logic;

    -- Register bus
    signal reg_miso_fsm         : reg_miso_type;
    signal reg_miso_cap         : reg_miso_type;
    signal reg_miso_dummy       : reg_miso_type;
begin

    -----------------------------------------------------------------------------
    --! @brief Finite State Machine which requests ADC data
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    adc_rd_rq_proc: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                cap_req           <= '0';
                reg_miso_fsm.ack  <= '0';
                reg_miso_fsm.data <= (others => '0');
                vswr_miso.valid   <= '0';
                vswr_miso.fwd     <= (others => '0');
                vswr_miso.rev     <= (others => '0');
                fsm_pwr_mon       <= IDLE;
            else
                -- Defaults                
                reg_miso_fsm.ack  <= '0';
                reg_miso_fsm.data <= (others => '0');
                vswr_miso.valid   <= '0';
                vswr_miso.fwd     <= (others => '0');
                vswr_miso.rev     <= (others => '0');

                case fsm_pwr_mon is
                    when IDLE =>
                        -- VSWR engine takes precedence and may block register access
                        if vswr_mosi.valid = '1' and vswr_mosi.addr = VSWR_ADDRESS then
                            -- VSWR engine read request
                            cap_req     <= '1';
                            fsm_pwr_mon <= VSWR_READ;
                        elsif reg_mosi.valid = '1' and reg_mosi.addr = REGISTER_ADDRESS and reg_mosi.rd_wr_n = '1' then
                            -- Register bus read request
                            cap_req     <= '1';
                            fsm_pwr_mon <= REG_READ;
                        else
                            cap_req     <= '0';
                        end if;

                    when REG_READ =>
                        if avg_data_valid = '1' then
                            reg_miso_fsm.ack  <= '1';
                            reg_miso_fsm.data <= "0000" & avg_data_rev &
                                                 "0000" & avg_data_fwd;
                            fsm_pwr_mon <= IDLE;
                        end if;

                    when VSWR_READ =>
                        -- Assign the output data to the appropriate bus
                        if avg_data_valid = '1' then
                            vswr_miso.valid <= '1';
                            vswr_miso.rev   <= avg_data_rev;
                            vswr_miso.fwd   <= avg_data_fwd;
                            fsm_pwr_mon     <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;

    i_pwr_mon_capture : entity work.pwr_mon_capture
    generic map (
        MAF_COEFF_ADDRESS    => MAF_COEFF_ADDRESS,
        MAF_DELAY_ADDRESS    => MAF_DELAY_ADDRESS
    )
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso_cap,
        
        -- Blanking Control
        int_blank_n         => int_blank_n,

        -- Capture Request
        cap_req             => cap_req,

        -- Outputs
        fwd_out             => avg_data_fwd,
        rev_out             => avg_data_rev,
        out_valid           => avg_data_valid,

        -- ADC signals
        adc_cs_n            => adc_cs_n,
        adc_sclk            => adc_sclk,
        adc_mosi            => adc_mosi,
        adc_miso            => adc_miso
    );

    i_reg_miso_mux: entity work.reg_miso_mux6
    port map (
        -- Clock
        reg_clk             => reg_clk,

        -- Input data/valid
        reg_miso_i_1        => reg_miso_fsm,
        reg_miso_i_2        => reg_miso_cap,
        reg_miso_i_3        => reg_miso_dummy,
        reg_miso_i_4        => reg_miso_dummy,
        reg_miso_i_5        => reg_miso_dummy,
        reg_miso_i_6        => reg_miso_dummy,

        -- Output data/valid
        reg_miso_o          => reg_miso
    );

    reg_miso_dummy.data <= (others => '0');
    reg_miso_dummy.ack  <= '0';
end rtl;
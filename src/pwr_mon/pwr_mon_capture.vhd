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

--! @brief Entity providing moving average filter for use with power monitor ADC
entity pwr_mon_capture is
    generic (
        MAF_COEFF_ADDRESS   : std_logic_vector(23 downto 0) := (others => '0');
        MAF_DELAY_ADDRESS   : std_logic_vector(23 downto 0) := (others => '0')
    );
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        reg_mosi            : in reg_mosi_type;                     --! Register master-out, slave-in signals
        reg_miso            : out reg_miso_type;                    --! Register master-in, slave-out signals
        
        -- Blanking Control
        int_blank_n         : in std_logic;                         --! Internal blanking signal

        -- Capture/Hold request
        cap_req             : in std_logic;                         --! Request a capture

        -- Outputs
        fwd_out             : out std_logic_vector(11 downto 0);    --! Forward ADC value output (averaged)
        rev_out             : out std_logic_vector(11 downto 0);    --! Reverse ADC value output (averaged)
        out_valid           : out std_logic;                        --! Outputs valid flag

        -- ADC signals
        adc_cs_n            : out std_logic;                        --! Active-low chip select to ADC
        adc_sclk            : out std_logic;                        --! Serial clock to ADC
        adc_mosi            : out std_logic;                        --! Serial data into ADC
        adc_miso            : in std_logic                          --! Serial data out of ADC
    );
end pwr_mon_capture;

architecture rtl of pwr_mon_capture is
    constant C_BLANK_TO_INVALID_DEFAULT : unsigned(15 downto 0) := to_unsigned(4e3, 16); -- 50 µs @ 80 MHz
    constant C_ACTIVE_TO_VALID_DEFAULT  : unsigned(15 downto 0) := to_unsigned(8e3, 16); -- 100 µs @ 80 MHz
    
    type mode_t is (BLOCK_AVG, MOVE_AVG);
    signal mode                     : mode_t := MOVE_AVG;
    signal mode_latched             : mode_t := MOVE_AVG;

    type fsm_capture_t is (IDLE, REQ_DATA, WAIT_DATA, RETURN_DATA, DELAY, DONE);
    signal fsm_capture              : fsm_capture_t := IDLE;

    signal read_req                 : std_logic := '0';

    signal coeff                    : std_logic_vector(18 downto 0);

    signal adc_data_fwd             : std_logic_vector(11 downto 0);
    signal adc_data_rev             : std_logic_vector(11 downto 0);
    signal adc_data_valid           : std_logic;

    signal mv_avg_fwd               : std_logic_vector(11 downto 0);
    signal mv_avg_rev               : std_logic_vector(11 downto 0);
    signal mv_avg_fwd_hold          : std_logic_vector(11 downto 0);
    signal mv_avg_rev_hold          : std_logic_vector(11 downto 0);
    signal mv_avg_in_valid          : std_logic;
    signal mv_avg_out_valid         : std_logic;    
    
    signal blk_avg_fwd              : std_logic_vector(11 downto 0);
    signal blk_avg_rev              : std_logic_vector(11 downto 0);
    signal blk_avg_out_valid        : std_logic;

    signal blank_count              : unsigned(15 downto 0);
    signal active_count             : unsigned(15 downto 0);
    signal capture_count            : unsigned(2 downto 0);
    signal delay_count              : unsigned(17 downto 0);
    signal delay_reg_val            : unsigned(15 downto 0);    
    
    -- RF Valid - is RF into the Power Monitor valid?
    signal rf_valid                 : std_logic;
    signal rf_invalidated           : std_logic;
    signal int_blank_n_r            : std_logic;
    
    -- Blank/Active to RF Invalid/Valid
    signal blank_to_invalid_reg_val : unsigned(15 downto 0);
    signal active_to_valid_reg_val  : unsigned(15 downto 0);
begin

    -----------------------------------------------------------------------------
    --! @brief Process which provides register access
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_regs: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                reg_miso.ack             <= '0';
                reg_miso.data            <= (others => '0');
                mode                     <= BLOCK_AVG;
                coeff                    <= (others => '0');
                delay_reg_val            <= (others => '0');
                blank_to_invalid_reg_val <= C_BLANK_TO_INVALID_DEFAULT;
                active_to_valid_reg_val  <= C_ACTIVE_TO_VALID_DEFAULT;
            else
                -- Defaults
                reg_miso.ack   <= '0';
                reg_miso.data  <= (others => '0');

                if reg_mosi.valid = '1' then
                    if reg_mosi.addr = MAF_COEFF_ADDRESS then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read
                            if mode = BLOCK_AVG then
                                reg_miso.data(31) <= '0';
                            else
                                reg_miso.data(31) <= '1';
                            end if;

                            reg_miso.data(coeff'range) <= coeff;
                            reg_miso.ack <= '1';
                        else
                            -- Write
                            if reg_mosi.data(31) = '0' then
                                mode <= BLOCK_AVG;
                            else
                                mode <= MOVE_AVG;
                            end if;

                            coeff <= reg_mosi.data(coeff'range);
                        end if;
                    elsif reg_mosi.addr = MAF_DELAY_ADDRESS then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read
                            reg_miso.data(delay_reg_val'range) <= std_logic_vector(delay_reg_val);
                            reg_miso.ack <= '1';
                        else
                            -- Write
                            delay_reg_val <= unsigned(reg_mosi.data(delay_reg_val'range));
                        end if;
                    elsif reg_mosi.addr = REG_ADDR_INT_PA_BLNK_TO_INVLD then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read
                            reg_miso.data(blank_to_invalid_reg_val'range) <= std_logic_vector(blank_to_invalid_reg_val);
                            reg_miso.ack <= '1';
                        else
                            -- Write
                            blank_to_invalid_reg_val <= unsigned(reg_mosi.data(blank_to_invalid_reg_val'range));
                        end if;
                    elsif reg_mosi.addr = REG_ADDR_INT_PA_ACTV_TO_VALID then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read
                            reg_miso.data(active_to_valid_reg_val'range) <= std_logic_vector(active_to_valid_reg_val);
                            reg_miso.ack <= '1';
                        else
                            -- Write
                            active_to_valid_reg_val <= unsigned(reg_mosi.data(active_to_valid_reg_val'range));
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Process which requests averaged ADC data
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_adc_req: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                read_req        <= '0';
                mv_avg_in_valid <= '0';
                rf_invalidated  <= '1';
                fsm_capture     <= IDLE;
            else
                -- Defaults
                read_req        <= '0';
                out_valid       <= '0';                
                
                -- If RF measurement was invalidated then do not push data into moving average
                mv_avg_in_valid <= adc_data_valid and (not rf_invalidated);

                case fsm_capture is
                    when IDLE =>
                        delay_count    <= (others => '0');
                        mode_latched   <= mode;
                        rf_invalidated <= '0';
                        
                        -- If we're in moving average mode then continuously request a new result
                        if mode = MOVE_AVG then
                            fsm_capture   <= REQ_DATA;
                            capture_count <= (others => '0');
                        -- Otherwise wait for a capture request
                        elsif cap_req = '1' then
                            fsm_capture   <= REQ_DATA;
                            capture_count <= to_unsigned(7, capture_count'length);
                        end if;

                    when REQ_DATA =>
                        -- Request data from ADC
                        read_req    <= '1';
                        delay_count <= (others => '0');
                        fsm_capture <= WAIT_DATA;

                    when WAIT_DATA =>
                        -- Wait for ADC to return data
                        delay_count <= (others => '0');
                        
                        -- During WAIT_DATA state, flag RF invalidated if rf_valid is low at any point
                        if rf_valid = '0' then
                            rf_invalidated <= '1';
                        end if;

                        if adc_data_valid = '1' then
                            capture_count <= capture_count - 1;
                            if capture_count > 0 then
                                fsm_capture <= REQ_DATA;
                            else
                                fsm_capture <= RETURN_DATA;
                            end if;
                        end if;

                    when RETURN_DATA =>
                        delay_count <= (others => '0');

                        if mode_latched = MOVE_AVG then                            
                            if rf_invalidated = '1' then
                                -- If RF was invalidated then there is no new data - just return
                                -- held data and return to IDLE. No delay, keep polling ADC 
                                -- until a valid measurement is captured and then delay will restart.
                                fwd_out         <= mv_avg_fwd_hold;
                                rev_out         <= mv_avg_rev_hold;
                                out_valid       <= '1';
                                fsm_capture     <= DONE;
                            elsif mv_avg_out_valid = '1' then
                                -- Output the new values
                                fwd_out         <= mv_avg_fwd;
                                rev_out         <= mv_avg_rev;                                
                                out_valid       <= '1';
                                -- Hold the new values, to be used when RF measurement is not valid
                                mv_avg_fwd_hold <= mv_avg_fwd;
                                mv_avg_rev_hold <= mv_avg_rev;
                                fsm_capture     <= DELAY;
                            end if;
                        else
                            if blk_avg_out_valid = '1' then
                                -- Output the block averaged values
                                fwd_out         <= blk_avg_fwd;
                                rev_out         <= blk_avg_rev;
                                out_valid       <= '1';
                                fsm_capture     <= DONE;
                            end if;
                        end if;

                    when DELAY =>
                        delay_count <= delay_count + 1;

                        -- Return to IDLE when the delay expires.
                        -- Delay 4x longer for timing resolution commonality with dock
                        if delay_count(17 downto 2) = delay_reg_val then                                                                               
                            -- If we're in moving average mode then continuously request a new result
                            -- skip straight to REQ_DATA from this state to save a clock cycle and preserve
                            -- the sampling delay at 6600 + (50 * DELAY) ns
                            if mode = MOVE_AVG then
                                fsm_capture    <= REQ_DATA;
                                capture_count  <= (others => '0');
                                rf_invalidated <= '0';
                            else
                                fsm_capture <= IDLE;
                            end if;
                        end if;
                    
                    when DONE =>
                        -- This state just skips one cycle so that cap_req can be reset by the higher-level controller
                        -- after it has seen out_valid asserted.
                        fsm_capture <= IDLE;
                        
                    when others =>
                        fsm_capture <= IDLE;

                end case;
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------------------
    --! @brief Process which indicates when RF is valid at Power Monitor ADC
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_rf_valid: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                rf_valid      <= '0';
                int_blank_n_r <= '0';
                blank_count   <= (others => '0');
                active_count  <= (others => '0');
            else
                int_blank_n_r <= int_blank_n;
                
                if int_blank_n = '0' then
                    -- Blanked                    
                    if blank_count < blank_to_invalid_reg_val then
                        blank_count <= blank_count + 1;
                    else
                        -- Blanked for duration in register, invalidate RF measurement
                        rf_valid <= '0';
                    end if;
                    
                    active_count <= (others => '0');
                else
                    -- If we have entered active state after a short blanking window then re-activate RF measurements
                    -- this allows meaurements to restart when they have been stopped by a long blanking
                    -- window and a short, fast repearting blanking window continues
                    if (int_blank_n_r = '0') and (blank_count < blank_to_invalid_reg_val) then
                        rf_valid <= '1';
                    end if;
                    
                    -- Active                                        
                    if active_count < active_to_valid_reg_val then
                        active_count <= active_count + 1;
                    else
                        -- Active for duration in register, validate RF measurement
                        rf_valid <= '1';
                    end if;
                    
                    blank_count <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    i_pwr_mon_spi_master: entity work.pwr_mon_spi_master
    port map(
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,

        -- Internal parallel bus
        read_req            => read_req,
        adc_data_fwd        => adc_data_fwd,
        adc_data_rev        => adc_data_rev,
        adc_data_valid      => adc_data_valid,

        -- ADC serial signals
        adc_cs_n            => adc_cs_n,
        adc_sclk            => adc_sclk,
        adc_mosi            => adc_mosi,
        adc_miso            => adc_miso
    );

    i_fwd_mv_avg: entity work.pwr_mon_moving_avg
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,

        coeff               => coeff,

        -- ADC input
        adc_in              => adc_data_fwd,
        adc_in_valid        => mv_avg_in_valid,
        avg_out             => mv_avg_fwd,
        avg_out_valid       => mv_avg_out_valid
    );

    i_rev_mv_avg: entity work.pwr_mon_moving_avg
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,

        coeff               => coeff,

        -- ADC input
        adc_in              => adc_data_rev,
        adc_in_valid        => mv_avg_in_valid,
        avg_out             => mv_avg_rev,
        avg_out_valid       => open
    );

    i_block_avg_fwd: entity work.pwr_mon_block_avg
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,

        -- ADC input
        adc_in              => adc_data_fwd,
        adc_in_valid        => adc_data_valid,
        avg_out             => blk_avg_fwd,
        avg_out_valid       => blk_avg_out_valid
    );

    i_block_avg_rev: entity work.pwr_mon_block_avg
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,

        -- ADC input
        adc_in              => adc_data_rev,
        adc_in_valid        => adc_data_valid,
        avg_out             => blk_avg_rev,
        avg_out_valid       => open
    );

end rtl;
----------------------------------------------------------------------------------
--! @file vswr_engine.vhd
--! @brief VSWR Engine Module
--!
--! Provides VSWR engine control - generates test lines, requests power monitor
--! test data and checks against thresholds
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
--! @version See Git logs
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

use work.mercury_pkg.all;
use work.reg_pkg.all;

--! @brief This entity controls the VSWR engine
--!
--! A FSM schedules tests, reads results and checks against the thresholds.
entity vswr_engine is
    generic (
        LINE_ADDR_BITS      : natural := 15
    );
    port (
        -- Register Bus
        reg_clk             : in std_logic;                                     --! The register clock
        reg_srst            : in std_logic;                                     --! Register synchronous reset
        reg_mosi            : in reg_mosi_type;                                 --! Register master-out, slave-in signals
        reg_miso            : out reg_miso_type;                                --! Register master-in, slave-out signals

        -- Jamming engine enable signal
        jam_en_n            : in std_logic;                                     --! Jamming engine enable (disable manual control)
        
        -- Blanking input
        int_blank_n         : in std_logic;                                     --! Internal blanking signal

        -- Blanking output
        blank_out_rev_n     : out std_logic;                                    --! Blanking output (active low) used to test reverse power after performing difference test and to "mute-on-fail"
        blank_out_all_n     : out std_logic;                                    --! Blanking output (active low) used to blank external sources whilst performing entire test

        -- VSWR engine signals
        vswr_line_addr      : out std_logic_vector(LINE_ADDR_BITS-1 downto 0);  --! VSWR test line base address
        vswr_line_req       : out std_logic;                                    --! Request VSWR test using line at vswr_line_addr
        vswr_line_ack       : in std_logic;                                     --! VSWR request being serviced
        vswr_mosi           : out vswr_mosi_type;                               --! VSWR engine power monitor master-out, slave-in signals
        vswr_miso           : in vswr_miso_type;                                --! VSWR engine power monitor master-in, slave-out signals
        vswr_line_start     : in std_logic;                                     --! Asserted high for one clock cycle when VSWR test line starts

        -- 1PPS signals
        int_pps             : in std_logic                                      --! Internal 1PPS signal, asserted high for one clock cycle per second
    );
end vswr_engine;

architecture rtl of vswr_engine is
    -- Constants
    -- Allow longer for the difference measurement to settle as we could have to wait that long anyway if the
    -- dock RS485 bus is in use. The dock comms module will reserve the bus whilst power settles. This means
    -- that the VSWR test will be consistent from test to test, rather than sometimes pushing the settling period out
    -- if the RS485 bus was in use by the register interface just before a VSWR request was made.
    constant C_PWR_SETTLE_DIFF          : unsigned(15 downto 0) := to_unsigned(56e3, 16); -- 700 us @ 80 MHz
    constant C_PWR_SETTLE_REV           : unsigned(15 downto 0) := to_unsigned(8e3, 16);  -- 100 us @ 80 MHz

    constant C_VSWR_FAIL_ACTIVE_DEFAULT : unsigned(9 downto 0)  := to_unsigned(50, 10);   -- 50 ms

    -- Finite State Machine
    type fsm_vswr_t is (IDLE, REQUEST_TEST,  WAIT_LINE_START,
                        POWER_SETTLING_DIFF, REQUEST_RESULT_DIFF, READ_RESULT_DIFF,
                        POWER_SETTLING_REV,  REQUEST_RESULT_REV,  READ_RESULT_REV,
                        RESULT_FLAG_GEN,     TONE_ADVANCE,        ZERO_RESULTS,
                        CONT_REQ_MEAS,       CONT_READ_MEAS);
    signal fsm_vswr : fsm_vswr_t := IDLE;

    -- Control
    signal vswr_test_start        : std_logic := '0';
    signal pps_det                : std_logic := '0';
    signal vswr_diff_fail         : std_logic := '0';
    signal vswr_rev_fail          : std_logic := '0';
    signal settle_count           : unsigned(15 downto 0);
    signal test_tone_nr           : unsigned(3 downto 0);
    signal line_addr              : unsigned(LINE_ADDR_BITS-1 downto 0);

    -- Thresholds/results
    type reg_diff_thresh_result_t is array (integer range 0 to 15) of std_logic_vector(15 downto 0);
    type reg_result_t             is array (integer range 0 to 15) of std_logic_vector(11 downto 0);

    signal reg_thresh_diff        : reg_diff_thresh_result_t := (others => (others => '0'));
    signal reg_thresh_rev         : reg_result_t  := (others => (others => '0'));

    signal reg_result_active_fwd  : reg_result_t  := (others => (others => '0'));
    signal reg_result_active_rev  : reg_result_t  := (others => (others => '0'));
    signal reg_result_blank_fwd   : reg_result_t  := (others => (others => '0'));
    signal reg_result_blank_rev   : reg_result_t  := (others => (others => '0'));

    signal vswr_result_a          : signed(15 downto 0);
    signal vswr_result_b          : signed(15 downto 0);
    signal vswr_result_diff       : signed(15 downto 0);
    signal vswr_result_diff_r     : signed(15 downto 0);
    signal vswr_result_rev        : unsigned(11 downto 0);
    signal vswr_result_fwd        : unsigned(11 downto 0);
    signal vswr_result_valid      : std_logic := '0';

    signal vswr_fail_flag         : std_logic;
    signal vswr_fail_flag_valid   : std_logic;

    -- VSWR fail active timer
    signal vswr_fail_active_time  : std_logic_vector(9 downto 0);

    -- Registers
    signal vswr_control           : std_logic_vector(14 downto 0) := (others => '0');
    signal vswr_window_offs       : std_logic_vector(9 downto 0)  := (others => '0');
    signal latest_result          : std_logic_vector(3 downto 0)  := (others => '0');
    signal vswr_status_reg        : std_logic_vector(16 downto 0) := (others => '0');
    signal jam_to_cvswr_valid     : unsigned(11 downto 0); --! Time from start of jamming to CVSWR valid, milliseconds
    signal blank_to_cvswr_invalid : unsigned(11 downto 0); --! Time from start of blanking to CVSWR valid, milliseconds
    
    alias  cont_vswr              : std_logic                     is vswr_control(11);
    alias  pwr_mon_sel            : std_logic_vector(1 downto 0)  is vswr_control(10 downto 9);
    alias  mute_on_fail           : std_logic                     is vswr_control(8);
    alias  test_period            : std_logic_vector(2 downto 0)  is vswr_control(7 downto 5);
    alias  nr_test_tones          : std_logic_vector(4 downto 0)  is vswr_control(4 downto 0); -- 0 = disabled
    alias  vswr_status            : std_logic_vector(15 downto 0) is vswr_status_reg(15 downto 0);
    alias  cvswr_invalid          : std_logic                     is vswr_status_reg(16);

    -- Second counter
    signal second_counter         : unsigned(2 downto 0) := (others => '0');

    -- Addresses
    signal vswr_start_addr        : std_logic_vector(LINE_ADDR_BITS-1 downto 0);

    -- Millisecond counters
    signal clk_count              : unsigned(16 downto 0) := (others => '0');
    signal clk_count_rf_active    : unsigned(16 downto 0) := (others => '0');
    signal ms_count               : unsigned(9 downto 0)  := (others => '0');
    signal ms_count_rf_active     : unsigned(9 downto 0)  := (others => '0');

    -- Timeout count
    signal timeout_count          : unsigned(15 downto 0); --! 16-bit timeout count gives 0.82 ms at 80 MHz
    
    -- CVSWR valid/invalid monitoring
    signal cvswr_blank_timer      : unsigned(11 downto 0);
    signal cvswr_active_timer     : unsigned(11 downto 0);
    signal cvswr_ms_timer         : unsigned(16 downto 0);
    
    -- Blanking control
    signal blank_rev_n            : std_logic;
    signal blank_all_n            : std_logic;

    -- Debug
    signal fsm_state_code         : std_logic_vector(3 downto 0);

begin
    with fsm_vswr select fsm_state_code <= x"0" when IDLE,
                                           x"1" when REQUEST_TEST,
                                           x"2" when WAIT_LINE_START,
                                           x"3" when POWER_SETTLING_DIFF,
                                           x"4" when REQUEST_RESULT_DIFF,
                                           x"5" when READ_RESULT_DIFF,
                                           x"6" when POWER_SETTLING_REV,
                                           x"7" when REQUEST_RESULT_REV,
                                           x"8" when READ_RESULT_REV,
                                           x"9" when RESULT_FLAG_GEN,
                                           x"a" when TONE_ADVANCE,
                                           x"b" when ZERO_RESULTS,
                                           x"c" when CONT_REQ_MEAS,
                                           x"d" when CONT_READ_MEAS,
                                           x"f" when others;
                                           
    blank_out_rev_n  <= blank_rev_n;
    blank_out_all_n  <= blank_all_n;

    -----------------------------------------------------------------------------
    --! @brief VSWR registers read/write process, synchronous to reg_clk.
    --!
    --! Provides read/write access to VSWR registers
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_reg_rd_wr: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                reg_miso.ack               <= '0';
                reg_thresh_rev             <= (others => (others => '0'));
                reg_thresh_diff            <= (others => (others => '0'));
                vswr_control               <= (others => '0');
                vswr_window_offs           <= (others => '0');
                vswr_fail_active_time      <= std_logic_vector(C_VSWR_FAIL_ACTIVE_DEFAULT);
            else
                -- Defaults
                reg_miso.data <= (others => '0');
                reg_miso.ack  <= '0';

                if reg_mosi.valid = '1' then
                    if unsigned(reg_mosi.addr) = unsigned(REG_ENG_1_VSWR_CONTROL) then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read VSWR control register
                            reg_miso.data(31 downto 28) <= latest_result;
                            reg_miso.data(vswr_control'range)  <= vswr_control;
                            reg_miso.ack <= '1';
                        else
                            -- Write VSWR control register
                            vswr_control <= reg_mosi.data(vswr_control'range);
                        end if;
                    elsif unsigned(reg_mosi.addr) = unsigned(REG_ENG_1_VSWR_STATUS) then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read VSWR status register
                            reg_miso.data(vswr_status_reg'range)  <= vswr_status_reg;
                            reg_miso.ack <= '1';
                        end if;
                    elsif unsigned(reg_mosi.addr) = unsigned(REG_ENG_1_VSWR_WINDOW_OFFS) then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read VSWR control register
                            reg_miso.data(vswr_window_offs'range) <= vswr_window_offs;
                            reg_miso.ack <= '1';
                        else
                            -- Write VSWR control register
                            vswr_window_offs <= reg_mosi.data(vswr_window_offs'range);
                        end if;
                    elsif unsigned(reg_mosi.addr) = unsigned(REG_ENG_1_VSWR_START_ADDR) then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read VSWR start address
                            reg_miso.data(LINE_ADDR_BITS-1 downto 0) <= vswr_start_addr;
                            reg_miso.ack <= '1';
                        else
                            -- Write VSWR start address
                            vswr_start_addr <= reg_mosi.data(LINE_ADDR_BITS-1 downto 0);
                        end if;
                    elsif unsigned(reg_mosi.addr) = unsigned(REG_ENG_1_VSWR_FAIL_ACTV_TIME) then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read VSWR Failure Active Time
                            reg_miso.data(vswr_fail_active_time'range) <= vswr_fail_active_time;
                            reg_miso.ack <= '1';
                        else
                            -- Write VSWR Failure Active Time
                            vswr_fail_active_time <= reg_mosi.data(vswr_fail_active_time'range);
                        end if;
                    elsif unsigned(reg_mosi.addr(23 downto 4)) = unsigned(REG_ENG_1_VSWR_THRESH_BASE(23 downto 4)) then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read VSWR thresholds
                            reg_miso.data(27 downto 16) <= reg_thresh_rev(to_integer(unsigned(reg_mosi.addr(3 downto 0))));
                            reg_miso.data(15 downto 0)  <= reg_thresh_diff(to_integer(unsigned(reg_mosi.addr(3 downto 0))));
                            reg_miso.ack <= '1';
                        else
                            -- Write VSWR thresholds
                            reg_thresh_rev(to_integer(unsigned(reg_mosi.addr(3 downto 0))))  <= reg_mosi.data(27 downto 16);
                            reg_thresh_diff(to_integer(unsigned(reg_mosi.addr(3 downto 0)))) <= reg_mosi.data(15 downto 0);
                        end if;
                    elsif unsigned(reg_mosi.addr(23 downto 5)) = unsigned(REG_ENG_1_VSWR_RESULT_BASE(23 downto 5)) then
                        if reg_mosi.rd_wr_n = '1' then
                            if reg_mosi.addr(0) = '0' then
                                -- Read VSWR "active" results (read-only)
                                reg_miso.data(27 downto 16) <= reg_result_active_rev(to_integer(unsigned(reg_mosi.addr(4 downto 1))));
                                reg_miso.data(11 downto 0)  <= reg_result_active_fwd(to_integer(unsigned(reg_mosi.addr(4 downto 1))));
                            else
                                -- Read VSWR "blanked" results (read-only)
                                reg_miso.data(27 downto 16) <= reg_result_blank_rev(to_integer(unsigned(reg_mosi.addr(4 downto 1))));
                                reg_miso.data(11 downto 0)  <= reg_result_blank_fwd(to_integer(unsigned(reg_mosi.addr(4 downto 1))));
                            end if;

                            reg_miso.ack <= '1';
                        end if;
                    elsif unsigned(reg_mosi.addr) = unsigned(REG_ENG_1_VSWR_FSM_STATE) then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read FSM state (read-only)
                            reg_miso.data(fsm_state_code'range) <= fsm_state_code;
                            reg_miso.ack <= '1';
                        end if;
                    elsif unsigned(reg_mosi.addr) = unsigned(REG_ADDR_JAM_TO_CVSWR_VALID) then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read Jam to CVSWR Valid time
                            reg_miso.data(jam_to_cvswr_valid'range) <= std_logic_vector(jam_to_cvswr_valid);
                        else
                            -- Write Jam to CVSWR Valid time
                            jam_to_cvswr_valid <= unsigned(reg_mosi.data(jam_to_cvswr_valid'range));
                        end if;
                        reg_miso.ack <= '1';
                    elsif unsigned(reg_mosi.addr) = unsigned(REG_ADDR_BLANK_TO_CVSWR_INVALID) then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read Blank to CVSWR Invalid time
                            reg_miso.data(blank_to_cvswr_invalid'range) <= std_logic_vector(blank_to_cvswr_invalid);
                        else
                            -- Write Blank to CVSWR Invalid time
                            blank_to_cvswr_invalid <= unsigned(reg_mosi.data(blank_to_cvswr_invalid'range));
                        end if;
                        reg_miso.ack <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    p_ms_count: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                pps_det <= '0';
            else
                if int_pps = '1' then
                    clk_count           <= (others => '0');
                    ms_count            <= (others => '0');
                    clk_count_rf_active <= (others => '0');
                    ms_count_rf_active  <= (others => '0');
                    pps_det             <= '1';
                elsif pps_det = '1' then
                    -- Count time (milliseconds) regardless of RF active state
                    if clk_count = to_unsigned(79999, clk_count'length) then
                        clk_count <= (others => '0');

                        if ms_count < "1111111111" then
                            ms_count <= ms_count + 1;
                        end if;
                    else
                        clk_count <= clk_count + 1;
                    end if;
                    
                    -- Count RF active time (milliseconds)
                    if int_blank_n = '1' then
                        if clk_count_rf_active = to_unsigned(79999, clk_count_rf_active'length) then
                            clk_count_rf_active <= (others => '0');

                            if ms_count_rf_active < "1111111111" then
                                ms_count_rf_active <= ms_count_rf_active + 1;
                            end if;
                        else
                            clk_count_rf_active <= clk_count_rf_active + 1;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process; 

    p_test_start: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                second_counter <= (others => '0');
                vswr_test_start <= '0';
            else
                -- Default
                vswr_test_start <= '0';

                if pps_det = '1' and ms_count = unsigned(vswr_window_offs) and clk_count = 0 then
                    if second_counter = 0 then
                        vswr_test_start <= '1';
                        second_counter <= unsigned(test_period);
                    else
                        second_counter <= second_counter - 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    p_vswr_result: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            vswr_result_a      <= "0000" & signed(vswr_miso.fwd);
            vswr_result_b      <= "0000" & signed(vswr_miso.rev);
            vswr_result_diff   <= vswr_result_a - vswr_result_b;
            vswr_result_diff_r <= vswr_result_diff;
        end if;
    end process;

    p_fsm: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if jam_en_n = '1' then
                fsm_vswr              <= IDLE;
                vswr_line_req         <= '0';
                vswr_mosi.valid       <= '0';
                vswr_mosi.vswr_period <= '0';
                vswr_diff_fail        <= '0';
                vswr_rev_fail         <= '0';
                vswr_fail_flag        <= '0';
                vswr_fail_flag_valid  <= '0';
                test_tone_nr          <= (others => '0');
                latest_result         <= (others => '0');
                line_addr             <= unsigned(vswr_start_addr);
                reg_result_active_fwd <= (others => (others => '0'));
                reg_result_active_rev <= (others => (others => '0'));
                reg_result_blank_fwd  <= (others => (others => '0'));
                reg_result_blank_rev  <= (others => (others => '0'));
            else
                -- Default
                vswr_mosi.valid      <= '0';
                vswr_fail_flag       <= '0';
                vswr_fail_flag_valid <= '0';

                case fsm_vswr is
                    when IDLE =>
                        -- De-assert VSWR period flag
                        vswr_mosi.vswr_period <= '0';

                        -- Reset the timeout count
                        timeout_count <= (others => '1');

                        -- Reset the failure flags
                        vswr_diff_fail <= '0';
                        vswr_rev_fail  <= '0';

                        -- Set the next requested line address
                        vswr_line_addr <= std_logic_vector(line_addr);

                        if cont_vswr = '1' then
                            -- Reset the tone number and the line address as the tone number
                            -- is used to index result flags. Reset line address so that it is
                            -- in sync with tone number in case continuous mode is exited and
                            -- legacy test-tone mode is re-entered.
                            test_tone_nr  <= (others => '0');
                            latest_result <= (others => '0');
                            line_addr     <= unsigned(vswr_start_addr);
                            fsm_vswr      <= CONT_REQ_MEAS;
                        elsif unsigned(nr_test_tones) /= 0 and vswr_test_start = '1' then
                            fsm_vswr      <= REQUEST_TEST;
                            vswr_line_req <= '1';
                        end if;

                    when REQUEST_TEST =>
                        if vswr_line_ack = '1' then
                            vswr_line_req <= '0';
                            fsm_vswr      <= WAIT_LINE_START;
                        end if;

                    when WAIT_LINE_START =>
                        if vswr_line_start = '1' then
                            fsm_vswr     <= POWER_SETTLING_DIFF;
                            settle_count <= C_PWR_SETTLE_DIFF;
                            -- Assert VSWR period flag
                            vswr_mosi.vswr_period <= '1';
                        end if;

                    when POWER_SETTLING_DIFF =>
                        if settle_count = 0 then
                            fsm_vswr     <= REQUEST_RESULT_DIFF;
                        else
                            settle_count <= settle_count - 1;
                        end if;

                    when REQUEST_RESULT_DIFF =>
                        vswr_mosi.addr  <= pwr_mon_sel;
                        vswr_mosi.valid <= '1';
                        fsm_vswr        <= READ_RESULT_DIFF;
                        -- Reset the timeout count
                        timeout_count   <= (others => '1');

                    when READ_RESULT_DIFF =>
                        if vswr_result_valid = '1' then
                            -- Write forward/reverse results to "active" registers
                            reg_result_active_fwd(to_integer(test_tone_nr)) <= std_logic_vector(vswr_result_fwd);
                            reg_result_active_rev(to_integer(test_tone_nr)) <= std_logic_vector(vswr_result_rev);

                            -- Test difference result against threshold (negative difference always fails)
                            if vswr_result_diff_r <= signed(reg_thresh_diff(to_integer(test_tone_nr))) then
                               vswr_diff_fail <= '1';
                            end if;

                            settle_count  <= C_PWR_SETTLE_REV;
                            fsm_vswr      <= POWER_SETTLING_REV;
                        elsif timeout_count = 0 then
                            -- If we hit timeout then flag a failure and zero results
                            fsm_vswr      <= ZERO_RESULTS;
                        else
                            timeout_count <= timeout_count - 1;
                        end if;

                    when POWER_SETTLING_REV =>
                        if settle_count = 0 then
                            -- Move to next state
                            fsm_vswr     <= REQUEST_RESULT_REV;
                        else
                            settle_count <= settle_count - 1;
                        end if;

                    when REQUEST_RESULT_REV =>
                        vswr_mosi.addr  <= pwr_mon_sel;
                        vswr_mosi.valid <= '1';
                        fsm_vswr        <= READ_RESULT_REV;
                        -- Reset the timeout count
                        timeout_count   <= (others => '1');

                    when READ_RESULT_REV =>
                        if vswr_result_valid = '1' then
                            -- Write forward/reverse results to "blank" registers
                            reg_result_blank_fwd(to_integer(test_tone_nr)) <= std_logic_vector(vswr_result_fwd);
                            reg_result_blank_rev(to_integer(test_tone_nr)) <= std_logic_vector(vswr_result_rev);

                            latest_result <= std_logic_vector(test_tone_nr);

                            -- Test reverse result against threshold
                            if vswr_result_rev >= unsigned(reg_thresh_rev(to_integer(test_tone_nr))) then
                                vswr_rev_fail <= '1';
                            end if;

                            fsm_vswr <= RESULT_FLAG_GEN;
                        elsif timeout_count = 0 then
                            -- If we hit timeout then flag a failure and zero results
                            fsm_vswr <= ZERO_RESULTS;
                        else
                            timeout_count <= timeout_count - 1;
                        end if;

                    when RESULT_FLAG_GEN =>
                        -- Generate new result flag
                        vswr_fail_flag_valid <= '1';

                        -- Generate failure if there was a failure in the difference measurement
                        -- and no failure in the reverse (blanked) measurement
                        if vswr_diff_fail = '1' and vswr_rev_fail = '0' then
                            vswr_fail_flag <= '1';
                        end if;

                        fsm_vswr <= TONE_ADVANCE;

                    when ZERO_RESULTS =>
                        -- Write zero results (state entered when power read fails)
                        reg_result_active_fwd(to_integer(test_tone_nr)) <= (others => '0');
                        reg_result_active_rev(to_integer(test_tone_nr)) <= (others => '0');
                        reg_result_blank_fwd(to_integer(test_tone_nr))  <= (others => '0');
                        reg_result_blank_rev(to_integer(test_tone_nr))  <= (others => '0');
                        latest_result <= std_logic_vector(test_tone_nr);

                        -- Generate new failure flag
                        vswr_fail_flag       <= '1';
                        vswr_fail_flag_valid <= '1';

                        fsm_vswr <= TONE_ADVANCE;

                    when TONE_ADVANCE =>
                        -- Move to the next test tone in advance of the next test
                        if resize(test_tone_nr, nr_test_tones'length) < unsigned(nr_test_tones) - 1 then
                            test_tone_nr   <= test_tone_nr + 1;
                            line_addr      <= line_addr + 5;
                        else
                            test_tone_nr   <= (others => '0');
                            line_addr      <= unsigned(vswr_start_addr);
                        end if;

                        fsm_vswr <= IDLE;

                    when CONT_REQ_MEAS =>
                        vswr_mosi.addr  <= pwr_mon_sel;
                        vswr_mosi.valid <= '1';
                        fsm_vswr        <= CONT_READ_MEAS;
                        -- Reset the timeout count
                        timeout_count   <= (others => '1');

                    when CONT_READ_MEAS =>
                        -- Zero out tone 0 "blank" registers
                        reg_result_blank_fwd(0) <= (others => '0');
                        reg_result_blank_rev(0) <= (others => '0');

                        if vswr_result_valid = '1' then
                            -- Write forward/reverse results to tone 0 "active" registers
                            reg_result_active_fwd(0) <= std_logic_vector(vswr_result_fwd);
                            reg_result_active_rev(0) <= std_logic_vector(vswr_result_rev);

                            -- Test difference result against tone 0 threshold (negative difference always fails)
                            if vswr_result_diff_r <= signed(reg_thresh_diff(0)) then
                               vswr_diff_fail <= '1';
                            end if;

                            -- Going via RESULT_FLAG_GEN/ZERO_RESULTS state means that TONE_ADVANCE state is entered,
                            -- don't need to advance tone number but it won't impact continuous mode. Tone number
                            -- will be reset to 0 again in IDLE state.
                            fsm_vswr <= RESULT_FLAG_GEN;
                        elsif timeout_count = 0 then
                            -- If we hit timeout then flag a failure and zero results.
                            fsm_vswr <= ZERO_RESULTS;
                        else
                            timeout_count <= timeout_count - 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    p_vswr_status: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            -- Clear status when VSWR engine or jamming engine is disabled
            if (unsigned(nr_test_tones) = 0 and cont_vswr = '0') or jam_en_n = '1' then
                vswr_status <= (others => '0');
            elsif vswr_fail_flag_valid = '1' then
                -- Set/clear status bit when flag is generated
                vswr_status(to_integer(test_tone_nr)) <= vswr_fail_flag;
            end if;
        end if;
    end process;

    p_blank: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                blank_rev_n <= '1';
                blank_all_n <= '1';
            else
                if cont_vswr = '1' then
                    -- Continuous VSWR mode...
                    
                    -- Defaults
                    blank_rev_n <= '1';
                    blank_all_n <= '1';
                                        
                    if mute_on_fail = '1' and vswr_status(0) = '1' then
                        -- If in failure state and mute-on-fail is active then mute after
                        -- the active time which is counted from the internal PPS event
                        if ms_count_rf_active >= unsigned(vswr_fail_active_time) then
                            -- Use the blank out reverse signal to blank as this is also
                            -- described in the ICD as the mute-on-fail blanking source.
                            blank_rev_n <= '0';
                        end if;
                    end if;            
                else
                    -- Legacy VSWR-tone mode...
                    if fsm_vswr = IDLE then                        
                        -- Generally stop blanking in idle state but start blanking
                        -- if failures have been detected and mute-on-fail bit is set.
                        -- In that failure case the "reverse blanking" output is used
                        -- to blank the sources selected through the blanking control register.
                        if mute_on_fail = '1' and unsigned(vswr_status) /= 0 then
                            blank_rev_n <= '0';
                        else
                            blank_rev_n <= '1';
                        end if;
                        blank_all_n <= '1';
                    elsif fsm_vswr = POWER_SETTLING_DIFF then
                        -- Start "complete VSWR test" blanking in this state (for use with external sources)
                        blank_all_n <= '0';
                        -- Stop reverse blanking in this state (in case it is set through "mute-on-fail"
                        blank_rev_n <= '1';
                    elsif fsm_vswr = POWER_SETTLING_REV then
                        -- Start reverse blanking in this state
                        blank_rev_n <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    p_cvswr_invalid: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if jam_en_n = '1' then
                cvswr_invalid      <= '1';
                cvswr_blank_timer  <= to_unsigned(1, cvswr_blank_timer'length);
                cvswr_active_timer <= to_unsigned(1, cvswr_active_timer'length);
                cvswr_ms_timer     <= (others => '1');
            else                
                if cvswr_invalid = '0' then
                    -- Been active for long enough, now check for prolonged blanking periods 
                    -- that are not commanded by this module ...
                    if int_blank_n = '0' and blank_rev_n = '1' then
                        if cvswr_ms_timer = to_unsigned(79999, cvswr_ms_timer'length) then
                            cvswr_ms_timer <= (others => '0');
                            if cvswr_blank_timer >= blank_to_cvswr_invalid then
                                cvswr_blank_timer <= to_unsigned(1, cvswr_blank_timer'length);
                                cvswr_ms_timer    <= (others => '1');
                                cvswr_invalid     <= '1';
                            else
                                cvswr_blank_timer <= cvswr_blank_timer + 1;
                            end if;
                        else
                            cvswr_ms_timer <= cvswr_ms_timer + 1;
                        end if;
                    else                    
                        cvswr_ms_timer    <= (others => '1');
                        cvswr_blank_timer <= to_unsigned(1, cvswr_blank_timer'length);
                    end if;
                elsif int_blank_n = '1' then
                    -- Count active time when not blanking
                    if cvswr_ms_timer = to_unsigned(79999, cvswr_ms_timer'length) then
                        cvswr_ms_timer <= (others => '0');
                        if cvswr_active_timer >= jam_to_cvswr_valid then
                            cvswr_active_timer <= to_unsigned(1, cvswr_active_timer'length);
                            cvswr_ms_timer     <= (others => '1');
                            cvswr_invalid      <= '0';                            
                        else
                            cvswr_active_timer <= cvswr_active_timer + 1;
                        end if;
                    else
                        cvswr_ms_timer <= cvswr_ms_timer + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    i_vswr_result_valid_dly: entity work.slv_delay
    generic map ( bits => 1, stages => 3 )
    port map (
        clk  => reg_clk,
        i(0) => vswr_miso.valid,
        o(0) => vswr_result_valid
    );

    i_vswr_result_rev_dly: entity work.unsigned_delay
    generic map ( bits => 12, stages => 3 )
    port map (
        clk => reg_clk,
        i   => unsigned(vswr_miso.rev),
        o   => vswr_result_rev
    );

    i_vswr_result_fwd_dly: entity work.unsigned_delay
    generic map ( bits => 12, stages => 3 )
    port map (
        clk => reg_clk,
        i   => unsigned(vswr_miso.fwd),
        o   => vswr_result_fwd
    );

end rtl;


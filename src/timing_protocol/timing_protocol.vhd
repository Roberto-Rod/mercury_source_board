----------------------------------------------------------------------------------
--! @file timing_protocol.vhd
--! @brief Timing Protocol module
--!
--! Provides asynchronous blanking source and all control registers related to
--! Timing Protocol
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

--! @brief Timing Protocol entity
--!
--! Provides asynchronous blanking source and all control
--! registers related to Timing Protocol
entity timing_protocol is
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        reg_mosi            : in reg_mosi_type;                     --! Register master-out, slave-in signals
        reg_miso            : out reg_miso_type;                    --! Register master-in, slave-out signals
        
        -- Receive test mode enable
        rx_test_en          : in std_logic;                         --! Receive test mode enable

        -- Blanking Input/Output
        tp_ext_blank_n      : in std_logic;                         --! Masked and synchronised external blanking input
        tp_async_blank_n    : out std_logic;                        --! Asynchronous Timing Protocol blanking output

        -- Tx/Rx Switch Control
        tx_rx_ctrl          : out std_logic;                        --! Tx/Rx switch control '1'=Tx, '0'=Rx

        -- DDS Line Restart
        dds_restart_prep    : out std_logic;                        --! Prepare DDS for line restart
        dds_restart_exec    : out std_logic;                        --! Execute DDS line restart

        -- Synchronous TP Enable
        tp_sync_en          : out std_logic;                        --! Synchronous Timing Protocol enable output

        -- 1PPS Input
        int_pps             : in std_logic;                         --! Intneral 1PPS in (synchronous to reg_clk, active for one clock, held over)
        ext_pps_present     : in std_logic                          --! External 1PPS status, '0' = not present, '1' = present
    );
end timing_protocol;

architecture rtl of timing_protocol is
    -- Constants
    constant C_TRANSITION_LENGTH   : integer := 24;
    constant C_MUTE_TO_RX          : unsigned := to_unsigned(  80, C_TRANSITION_LENGTH+2); --! 1 µs at 80 MHz (t_mute)
    constant C_TX_TO_UNMUTE        : unsigned := to_unsigned( 320, C_TRANSITION_LENGTH+2); --! 4 µs at 80 MHz (t_guard + t_sw_tx)
    constant C_MIN_RX_WINDOW       : unsigned := to_unsigned(6400, C_TRANSITION_LENGTH+2); --! 80 µs at 80 MHz

    -- Timing Protocol control register
    signal ctrl_reg                : std_logic_vector(7 downto 0);
    alias  num_async_transitions   : std_logic_vector(3 downto 0) is ctrl_reg(7 downto 4); -- 0x0 = 1 transition ... 0xF = 16 transitions
    alias  action_on_sync_loss     : std_logic                    is ctrl_reg(3);          -- '0' = continue, '1' = blank
    alias  first_async_period      : std_logic                    is ctrl_reg(2);          -- '0' = blank,    '1' = active
    alias  tp_mode                 : std_logic_vector(1 downto 0) is ctrl_reg(1 downto 0); -- 0x0 = disabled, 0x1 = async, 0x2 = sync, 0x3 = force rx (test mode)

    -- Timing Protocol holdover time register, sync loss counter & sync flags
    signal holdover_time_reg       : std_logic_vector(15 downto 0);
    signal sync_loss_count         : unsigned(15 downto 0);
    signal in_sync                 : std_logic;
    signal first_sync              : std_logic;
    signal transition_at_zero      : std_logic;

    -- Timing Protocol transition time register RAM signals
    signal transition_we           : std_logic;
    signal transition_addr_a       : std_logic_vector(REG_ADDR_BITS_TP_TRANSITION-1 downto 0);
    signal transition_addr_a_valid : std_logic;
    signal transition_addr_b       : std_logic_vector(REG_ADDR_BITS_TP_TRANSITION-1 downto 0);
    signal transition_addr_b_valid : std_logic;
    signal transition_din_a        : std_logic_vector(C_TRANSITION_LENGTH-1 downto 0);
    signal transition_dout_a       : std_logic_vector(C_TRANSITION_LENGTH-1 downto 0);
    signal transition_dout_a_valid : std_logic;
    signal transition_dout_b       : std_logic_vector(C_TRANSITION_LENGTH-1 downto 0);
    signal transition_dout_b_valid : std_logic;

    -- Timing Protocol timer is 3 bits longer than transition length so transition resolution is 8 x reg_clk period.
    -- reg_clk period is 12.5 ns, transition resolution is 0.1 us
    signal tp_timer                : unsigned(C_TRANSITION_LENGTH+2 downto 0);
    signal transition_count        : unsigned(REG_ADDR_BITS_TP_TRANSITION-1 downto 0);
    signal tx_to_rx_time           : unsigned(C_TRANSITION_LENGTH+2 downto 0);
    signal rx_to_tx_time           : unsigned(C_TRANSITION_LENGTH+2 downto 0);

    -- Internal asynchronous blanking signal
    signal blank_n_int             : std_logic;
    signal blank_n_int_r           : std_logic;
    signal blank_n_int_rr          : std_logic;
    signal blank_n_int_rrr         : std_logic;
    signal blank_n_masked_int      : std_logic;
    signal tx_rx_ctrl_int          : std_logic;
begin
    -----------------------------------------------------------------------------
    --! Asynchronous Assignments
    -----------------------------------------------------------------------------
    with tp_mode select tp_sync_en <= '1' when "10",
                                      '0' when others;

    tp_async_blank_n <= blank_n_masked_int;

    -----------------------------------------------------------------------------
    --! @brief Register read/write process, synchronous to reg_clk.
    --!
    --! Handles TP registers
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_reg_rd_wr: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                -- Synchronous Reset
                ctrl_reg                <= (others => '0');
                holdover_time_reg       <= x"001E";
                transition_at_zero      <= '0';
                transition_we           <= '0';
                transition_addr_a       <= (others => '0');
                transition_addr_a_valid <= '0';
                transition_din_a        <= (others => '0');
                reg_miso.ack            <= '0';
                reg_miso.data           <= (others => '0');
            else
                -- Defaults
                reg_miso.ack            <= '0';
                reg_miso.data           <= (others => '0');
                transition_we           <= '0';
                transition_addr_a       <= reg_mosi.addr(REG_ADDR_BITS_TP_TRANSITION-1 downto 0);
                transition_addr_a_valid <= '0';

                if reg_mosi.valid = '1' then
                    -- TP Control Register
                    if reg_mosi.addr = REG_ADDR_TP_CONTROL then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read
                            reg_miso.data(ctrl_reg'high downto 0) <= ctrl_reg;
                        else
                            -- Write
                            ctrl_reg <= reg_mosi.data(ctrl_reg'high downto 0);
                        end if;
                        reg_miso.ack <= '1';
                    -- TP Holdover Time
                    elsif reg_mosi.addr = REG_ADDR_TP_HOLDOVER then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read
                            reg_miso.data(holdover_time_reg'high downto 0) <= holdover_time_reg;
                        else
                            -- Write
                            holdover_time_reg <= reg_mosi.data(holdover_time_reg'high downto 0);
                        end if;
                        reg_miso.ack <= '1';
                    -- TP Transition Times
                    elsif reg_mosi.addr(23 downto REG_ADDR_BITS_TP_TRANSITION) = REG_ADDR_TP_TRANSITION_BASE(23 downto REG_ADDR_BITS_TP_TRANSITION) then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read
                            transition_addr_a_valid <= '1';
                        else
                            -- Write
                            transition_din_a <= reg_mosi.data(C_TRANSITION_LENGTH-1 downto 0);
                            transition_we    <= '1';
                            reg_miso.ack     <= '1';

                            -- Is the first transition being set at time zero?
                            if reg_mosi.addr(REG_ADDR_BITS_TP_TRANSITION-1 downto 0) = 0 then
                                if reg_mosi.data = 0 then
                                    transition_at_zero <= '1';
                                else
                                    transition_at_zero <= '0';
                                end if;
                            end if;
                        end if;
                    end if;
                elsif transition_dout_a_valid = '1' then
                    -- Return the transition RAM data
                    reg_miso.data(C_TRANSITION_LENGTH-1 downto 0) <= transition_dout_a;
                    reg_miso.ack                                  <= '1';
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Asynchronous Timing Protocol process, synchronous to reg_clk.
    --!
    --! Generates the asynchronous blanking pattern
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_async_tp: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            -- Reset everything and de-assert blanking if not in async mode
            if reg_srst = '1' or tp_mode /= x"01" then
                tp_timer                <= (0 => '1', others => '0');
                transition_count        <= (others => '0');
                transition_addr_b       <= (others => '0');
                transition_addr_b_valid <= '0';
                blank_n_int             <= '1';
            else
                transition_addr_b       <= std_logic_vector(transition_count);
                transition_addr_b_valid <= '1';

                if int_pps = '1' then
                    -- On 1PPS, reset the TP time and the transition counter
                    tp_timer                <= (0 => '1', others => '0');
                    transition_addr_b_valid <= '0';

                    if transition_at_zero = '0' then
                        -- No transition at zero, reset counter to 0
                        transition_count <= to_unsigned(0, transition_count'length);
                        blank_n_int      <= first_async_period;
                    else
                        -- Transition at zero, reset counter to 1
                        -- and invert state
                        transition_count <= to_unsigned(1, transition_count'length);
                        blank_n_int      <= not first_async_period;
                    end if;
                elsif first_sync = '0' then
                    -- Haven't seen internal sync yet, blank output
                    blank_n_int <= '0';
                else
                    tp_timer <= tp_timer + 1;

                    -- Wait for the next transition and then change state
                    if tp_timer(tp_timer'high downto 3) >= unsigned(transition_dout_b) and transition_addr_b_valid = '1' and transition_dout_b_valid = '1' then
                        transition_addr_b_valid <= '0';

                        -- Advance the transition counter
                        if (transition_count < unsigned(num_async_transitions)) then
                            transition_count <= transition_count + 1;

                            -- Change blank state
                            blank_n_int <= not blank_n_int;
                        else
                            -- When all transitions have been made, reset the TP timer and
                            -- the transition counter to repeat the pattern
                            tp_timer         <= (0 => '1', others => '0');

                            -- On the last transition, rather than change state, go back to the first async period state
                            -- if there are an even number of transitions then this will be a state change, if there
                            -- are an odd number then this will not be a state change.
                            if transition_at_zero = '0' then
                                -- No transition at zero, reset counter to 0
                                transition_count <= to_unsigned(0, transition_count'length);
                                blank_n_int      <= first_async_period;
                            else
                                -- Transition at zero, reset counter to 1
                                -- and invert state
                                transition_count <= to_unsigned(1, transition_count'length);
                                blank_n_int      <= not first_async_period;
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Tx/Rx control generation
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_tx_rx_ctrl: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            -- Reset everything and de-assert blanking if not in async mode
            if reg_srst = '1' or tp_mode /= x"01" then
                blank_n_int_r   <= '0';
                blank_n_int_rr  <= '0';
                blank_n_int_rrr <= '0';
                tx_rx_ctrl_int  <= '1';
                tx_to_rx_time   <= (others => '1');
                rx_to_tx_time   <= (others => '1');
            elsif first_sync = '1' then
                blank_n_int_r   <= blank_n_int;
                blank_n_int_rr  <= blank_n_int_r;
                blank_n_int_rrr <= blank_n_int_rr;

                if int_pps = '1' then
                    tx_rx_ctrl_int <= '1';
                    tx_to_rx_time  <= (others => '1');
                    rx_to_tx_time  <= (others => '1');
                -- On falling edge of blank_n, trigger timer
                elsif blank_n_int_rrr = '1' and blank_n_int_rr = '0' then
                    if unsigned(transition_dout_b & "000") > (tp_timer + C_MIN_RX_WINDOW - 3) then
                        tx_to_rx_time  <= tp_timer + (C_MUTE_TO_RX - 3);
                        rx_to_tx_time  <= unsigned(transition_dout_b & "000") - C_TX_TO_UNMUTE;
                    else
                        tx_rx_ctrl_int <= '1';
                        tx_to_rx_time  <= (others => '1');
                        rx_to_tx_time  <= (others => '1');
                    end if;
                else
                    if tp_timer = rx_to_tx_time then
                        tx_rx_ctrl_int <= '1';
                    elsif tp_timer = tx_to_rx_time then
                        tx_rx_ctrl_int <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Asynchronous blanking output process
    --!
    --! Routes the asynchronous blanking signal and asserts blanking if 1PPS sync
    --! is lost and action on sync loss is to blank.
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_blank_out: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                blank_n_masked_int <= '1';
                tx_rx_ctrl         <= '1';
            else
                if rx_test_en = '1' or tp_mode = x"11" then
                    -- Test mode, blank PA, switch to receive
                    blank_n_masked_int <= '0';
                    tx_rx_ctrl         <= '0';
                elsif tp_mode = x"00" then
                    -- TP disabled, do not blank or receive
                    blank_n_masked_int <= '1';
                    tx_rx_ctrl         <= '1';                    
                else
                    -- TP enabled (async or sync mode)
                    if in_sync = '0' and action_on_sync_loss = '1' then
                        -- Not synchronised and action on sync loss is to blank
                        blank_n_masked_int <= '0';
                        -- Don't receive in this state
                        tx_rx_ctrl         <= '1';
                    else
                        -- Synchronised - register blanking signal out of module
                        blank_n_masked_int <= blank_n_int;
                        tx_rx_ctrl         <= tx_rx_ctrl_int;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Sync loss detection process
    --!
    --! Detects ext. 1PPS lost flag and counts number of seconds (using internal 1PPS)
    --! flags sync loss when holdover time as passed.
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_sync_loss: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                -- Reset state is "not in sync" until sync is detected
                in_sync         <= '0';
                first_sync      <= '0';
                sync_loss_count <= (others => '0');
            else
                if tp_mode = "01" then
                    -- In asynchronous TP mode

                    -- When we get a 1PPS pulse...
                    if int_pps = '1' then
                        -- Assert first sync flag which latches until async mode is disabled
                        first_sync <= '1';

                        -- ... if external 1PPS is present then we are now synchronised...
                        if ext_pps_present = '1' then
                            in_sync         <= '1';
                            sync_loss_count <= (others => '0');
                        -- ... otherwise start counting, when holdover time is met then we are not synchronised
                        else
                            if sync_loss_count = unsigned(holdover_time_reg) then
                                in_sync <= '0';
                            else
                                sync_loss_count <= sync_loss_count + 1;
                            end if;
                        end if;
                    end if;
                else
                    -- Not in asynchronous TP mode - reset sync flags
                    in_sync         <= '0';
                    first_sync      <= '0';
                    sync_loss_count <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief DDS line restart command module
    -----------------------------------------------------------------------------
    i_tp_dds_restart: entity work.tp_dds_restart
    port map (
        -- Register Bus
        clk                 => reg_clk,
        srst                => reg_srst,

        -- Blanking Inputs
        tp_ext_blank_n      => tp_ext_blank_n,
        tp_async_blank_n    => blank_n_masked_int,

        -- DDS Line Restart
        dds_restart_prep    => dds_restart_prep,
        dds_restart_exec    => dds_restart_exec
    );

    -----------------------------------------------------------------------------
    --! @brief Timing Protocol Transition Register RAM
    -----------------------------------------------------------------------------
    i_tp_transition_ram: entity work.tp_transition_ram
    generic map (
        ADDR_BITS   => REG_ADDR_BITS_TP_TRANSITION,
        DATA_BITS   => C_TRANSITION_LENGTH
    )
    port map (
        clk        => reg_clk,
        we         => transition_we,
        a          => transition_addr_a,
        a_valid    => transition_addr_a_valid,
        dpra       => transition_addr_b,
        dpra_valid => transition_addr_b_valid,
        di         => transition_din_a,
        spo        => transition_dout_a,
        spo_valid  => transition_dout_a_valid,
        dpo        => transition_dout_b,
        dpo_valid  => transition_dout_b_valid
    );

end rtl;

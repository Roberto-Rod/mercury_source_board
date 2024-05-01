----------------------------------------------------------------------------------
--! @file pps_sync_tb.vhd
--! @brief Testbench for 1PPS synchronisation module
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
--! @version See Git logs
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

use work.reg_pkg.all;

library bitvis_util;
use bitvis_util.types_pkg.all;
use bitvis_util.string_methods_pkg.all;
use bitvis_util.adaptations_pkg.all;
use bitvis_util.methods_pkg.all;

library bitvis_vip_reg;
use bitvis_vip_reg.reg_bfm_pkg.all;

library tb_support;
use tb_support.tb_support_pkg.all;

--! @brief Testbench for 1PPS synchronisation module
entity pps_sync_tb is
end pps_sync_tb;

architecture tb of pps_sync_tb is
    -- Register Bus
    signal reg_clk_i           : std_logic := '0';                             --! The register clock
    signal reg_srst_i          : std_logic := '0';                             --! Register synchronous reset
    signal reg_mosi_i          : reg_mosi_type;                                --! Register master-out, slave-in signals
    signal reg_miso_o          : reg_miso_type;                                --! Register master-in, slave-out signals

    -- 1PPS signals
    signal ext_pps_i           : std_logic;                                    --! External 1PPS input signal
    signal ext_pps_o           : std_logic;                                    --! External 1PPS output signal
    signal int_pps_o           : std_logic;                                    --! FPGA internal 1PPS signal
    signal ext_pps_present_o   : std_logic;                                    --! Flag indicating presence of external 1PPS signal (asserted high)

    -- Clock count out
    signal clk_count_o         : std_logic_vector(26 downto 0);                --! Number of clocks (80 MHz) counted between each off-air 1PPS
    signal clk_count_valid_o   : std_logic;                                    --! Flag asserted when new count available

    -- Clock enable flag and clock period
    signal clock_ena       : boolean := false;
    constant C_CLK_PERIOD  : time    := 12.5 ns;
begin
    i_dut: entity work.pps_sync
    generic map(
        PPS_THRESH    => 8000,
        PPS_ERROR     => 200,
        CLKS_PER_PPS  => 8000
    )
    port map(
        -- Register Bus
        reg_clk_i           => reg_clk_i,
        reg_srst_i          => reg_srst_i,
        reg_mosi_i          => reg_mosi_i,
        reg_miso_o          => reg_miso_o,

        -- 1PPS signals
        ext_pps_i           => ext_pps_i,
        ext_pps_o           => ext_pps_o,
        int_pps_o           => int_pps_o,
        ext_pps_present_o   => ext_pps_present_o,

        -- Clock count out
        clk_count_o         => clk_count_o,
        clk_count_valid_o   => clk_count_valid_o
    );

    -- Set up the clock generator
    clock_gen(reg_clk_i, clock_ena, C_CLK_PERIOD);

    ------------------------------------------------
    -- PROCESS: p_main
    ------------------------------------------------
    p_main: process
        -- Define a locked write register config which gives no alert on failure (as we expect no ack back)
        constant C_REG_CONFIG_LOCKED_WR : t_reg_config := (max_wait_cycles => 100,
                                                           max_wait_cycles_severity => NO_ALERT);

        -- Register addresses
        constant C_REG_PPS_CNT      : std_logic_vector(23 downto 0) := x"000005";

        procedure set_inputs_passive(dummy : t_void) is
        begin
            reg_mosi_i.data    <= (others => '0');
            reg_mosi_i.addr    <= (others => '0');
            reg_mosi_i.rd_wr_n <= '0';
            reg_mosi_i.valid   <= '0';
            ext_pps_i          <= '0';
            log(ID_SEQUENCER_SUB, "All inputs set passive", C_SCOPE);
        end;

        -- Overloads for PIF BFMs for register interface
        procedure write(
            constant addr_value   : in std_logic_vector;
            constant data_value   : in std_logic_vector;
            constant msg          : in string;
            constant reg_config   : in t_reg_config := C_REG_CONFIG_DEFAULT) is
        begin
            reg_write(addr_value, data_value, msg, reg_clk_i, reg_mosi_i.addr, reg_mosi_i.data,
                      reg_mosi_i.rd_wr_n, reg_mosi_i.valid, reg_miso_o.ack, C_CLK_PERIOD, C_SCOPE, shared_msg_id_panel, reg_config);
        end;

        procedure read(
            constant addr_value   : in std_logic_vector;
            variable data_value   : out std_logic_vector;
            constant msg          : in string) is
        begin
            reg_read(addr_value, data_value, msg, reg_clk_i, reg_mosi_i.addr, reg_mosi_i.rd_wr_n, reg_mosi_i.valid,
                     reg_miso_o.data, reg_miso_o.ack,  C_CLK_PERIOD, C_SCOPE);
        end;

        procedure check(
            constant addr_value   : in std_logic_vector;
            constant data_exp     : in std_logic_vector;
            constant alert_level  : in t_alert_level;
            constant msg          : in string) is
        begin
            reg_check(addr_value, data_exp, alert_level, msg, reg_clk_i, reg_mosi_i.addr, reg_mosi_i.rd_wr_n,
                      reg_mosi_i.valid, reg_miso_o.data, reg_miso_o.ack,  C_CLK_PERIOD, C_SCOPE);
        end;

    begin
        -- Print the configuration to the log
        report_global_ctrl(VOID);
        report_msg_id_panel(VOID);

        enable_log_msg(ALL_MESSAGES);

        log(ID_LOG_HDR, "Start Simulation of TB for freq_trim", C_SCOPE);
        ------------------------------------------------------------
        set_inputs_passive(VOID);
        clock_ena <= true;   -- to start clock generator
        pulse(reg_srst_i, reg_clk_i, 10, "Pulsed reset-signal - active for 10T");

        log(ID_LOG_HDR, "Check defaults on output ports", C_SCOPE);
        ------------------------------------------------------------
        check_value(reg_miso_o.ack,          '0', ERROR, "Register master-out, slave-in ack default");
        check_value(reg_miso_o.data, x"00000000", ERROR, "Register master-out, slave-in data default");
        check_value(ext_pps_present_o,       '0', ERROR, "ext_pps_present_o default");
        check_value(clk_count_valid_o,       '0', ERROR, "clk_count_valid_o default");

        wait for 1 us;

        log(ID_LOG_HDR, "Check register defaults", C_SCOPE);
        ------------------------------------------------------------
        check(C_REG_PPS_CNT, x"FFFFFFFF", ERROR, "PPS Count Register default");

        log(ID_LOG_HDR, "Issue regular pulses", C_SCOPE);
        ------------------------------------------------------------
        wait for 2.34568 us;
        for i in 1 to 10 loop
            wait for 10 us;
            ext_pps_i <= '0';
            wait for 90 us;
            ext_pps_i <= '1';
        end loop;

        await_value(clk_count_valid_o, '1', 0 ns, 100 ns, ERROR, "Clock count valid: transition high");
        check_value(clk_count_o,       x"00001F40",       ERROR, "Clock count: should be 8000 (decimal)");
        check_value(ext_pps_present_o, '1', ERROR, "External PPS present: should be high");
        
        ext_pps_i <= '0';

        log(ID_LOG_HDR, "Issue another pulse early and follow it with one a second later", C_SCOPE);
        ------------------------------------------------------------
        wait for 10 us;
        ext_pps_i <= '1';
        wait for 10 us;
        ext_pps_i <= '0';

        check_value(ext_pps_present_o, '0', ERROR, "External PPS present: should be low");

        wait for 90 us;
        ext_pps_i <= '1';
        wait for 10 us;
        ext_pps_i <= '0';

        check_value(ext_pps_present_o, '1', ERROR, "External PPS present: should be high");

        log(ID_LOG_HDR, "Issue another pulse late and follow it with one a second later", C_SCOPE);
        ------------------------------------------------------------
        wait for 1300 ns;
        ext_pps_i <= '1';
        wait for 10 us;
        ext_pps_i <= '0';

        check_value(ext_pps_present_o, '0', ERROR, "External PPS present: should be low");

        wait for 90 us;
        ext_pps_i <= '1';
        wait for 10 us;
        ext_pps_i <= '0';

        check_value(ext_pps_present_o, '1', ERROR, "External PPS present: should be high");

        log(ID_LOG_HDR, "Issue another pulse early", C_SCOPE);
        ------------------------------------------------------------
        wait for 10 us;
        ext_pps_i <= '1';
        wait for 10 us;
        ext_pps_i <= '0';
        
        check_value(ext_pps_present_o, '0', ERROR, "External PPS present: should be low");

        -- Wait for a while
        wait for 10 us;

        log(ID_LOG_HDR, "Issue a sequence of pulses which are slightly early each time", C_SCOPE);
        ------------------------------------------------------------
        for i in 1 to 10 loop
            ext_pps_i <= '1';
            wait for 10 us;
            ext_pps_i <= '0';
            wait for 88 us;
        end loop;
        
        check_value(ext_pps_present_o, '1', ERROR, "External PPS present: should be high");
        
        log(ID_LOG_HDR, "Issue a long sequence of pulses", C_SCOPE);
        ------------------------------------------------------------
        wait for 1 ms;
        
        for i in 1 to 25 loop
            ext_pps_i <= '1';
            wait for 10 us;
            ext_pps_i <= '0';
            wait for 90 us;
        end loop;
        
        wait for 1 ms + 75 ns;
        
        for i in 1 to 25 loop
            ext_pps_i <= '1';
            wait for 10 us;
            ext_pps_i <= '0';
            wait for 90 us;
        end loop;
        
        wait for 1 ms - 75 ns;
        
        for i in 1 to 25 loop
            ext_pps_i <= '1';
            wait for 10 us;
            ext_pps_i <= '0';
            wait for 90 us;
        end loop;
        
        --==================================================================================================
        -- Ending the simulation
        --------------------------------------------------------------------------------------
        wait for 1000 ns;             -- to allow some time for completion
        report_alert_counters(FINAL); -- Report final counters and print conclusion for simulation (Success/Fail)
        log(ID_LOG_HDR, "SIMULATION COMPLETED", C_SCOPE);
        clock_ena <= false;           -- to gracefully stop the simulation - if possible
        -- Hopefully stops when clock is stopped. Otherwise force a stop.
        assert false
        report "End of simulation.  (***Ignore this failure. Was provoked to stop the simulation.)"
        severity failure;
        wait;  -- to stop completely

    end process p_main;
end tb;
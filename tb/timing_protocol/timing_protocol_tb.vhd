----------------------------------------------------------------------------------
--! @file timing_protocol_tb.vhd
--! @brief Testbench for Timing Protocol module
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

entity timing_protocol_tb is
end timing_protocol_tb;

----------------------------------------------------------------------------------
--! @brief Testbench for Timing Protocol module
----------------------------------------------------------------------------------
architecture tb of timing_protocol_tb is
    -- Register Bus
    signal reg_clk             : std_logic := '0'; --! The register clock
    signal reg_srst            : std_logic := '0'; --! Register synchronous reset
    signal reg_mosi            : reg_mosi_type;    --! Register master-out, slave-in signals
    signal reg_miso            : reg_miso_type;    --! Register master-in, slave-out signals
    
    -- Receive test mode enable
    signal rx_test_en          : std_logic := '0'; --! Receive test mode enable    

    -- Blanking Input/Output
    signal tp_ext_blank_n      : std_logic;        --! Asynchronous external blanking input
    signal tp_async_blank_n    : std_logic;        --! Asynchronous Timing Protocol blanking output
    
    -- Tx/Rx Switch Control
    signal tx_rx_ctrl          : std_logic;        --! Tx/Rx switch control
    
    -- Synchronous TP Enable
    signal tp_sync_en          : std_logic;        --! Synchronous Timing Protocol enable output
    
    -- 1PPS Input
    signal int_pps             : std_logic;        --! Intneral 1PPS in (synchronous to reg_clk, active for one clock, held over)
    signal ext_pps_present     : std_logic;        --! External 1PPS status, '0' = not present, '1' = present
    
    -- Clock enable flag and clock period
    signal clock_ena       : boolean := false;
    constant C_CLK_PERIOD  : time    := 12.5 ns;
begin
    i_dut: entity work.timing_protocol
    port map(
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi,
        reg_miso            => reg_miso,
        
        -- Receive test mode enable
        rx_test_en          => rx_test_en,

        -- Blanking Input/Output
        tp_ext_blank_n      => tp_ext_blank_n,
        tp_async_blank_n    => tp_async_blank_n,
        
        -- Tx/Rx Switch Control
        tx_rx_ctrl          => tx_rx_ctrl,
        
        -- Synchronous TP Enable
        tp_sync_en          => tp_sync_en,
        
        -- 1PPS Input
        int_pps             => int_pps,
        ext_pps_present     => ext_pps_present
    );
    
    -- Set up the clock generator
    clock_gen(reg_clk, clock_ena, C_CLK_PERIOD);
    
    ------------------------------------------------
    -- PROCESS: p_main
    ------------------------------------------------
    p_main: process
        -- Define a locked write register config which gives no alert on failure (as we expect no ack back)
        constant C_REG_CONFIG_LOCKED_WR : t_reg_config := (max_wait_cycles => 100,
                                                           max_wait_cycles_severity => NO_ALERT);
                                                           
        -- Blanking control address
        constant C_BLANK_CONTROL    : std_logic_vector(23 downto 0) := x"000162";
        
        -- TP register addresses
        type t_address_block is array (integer range 1 to 16) of std_logic_vector(23 downto 0);        
        constant C_TP_TRANSITION : t_address_block := (x"000180", x"000181", x"000182", x"000183",
                                                       x"000184", x"000185", x"000186", x"000187",
                                                       x"000188", x"000189", x"00018A", x"00018B",
                                                       x"00018C", x"00018D", x"00018E", x"00018F");

        constant C_TP_CONTROL  : std_logic_vector(23 downto 0) := x"000190";
        constant C_TP_HOLDOVER : std_logic_vector(23 downto 0) := x"000191";
        
        procedure set_inputs_passive(dummy : t_void) is
        begin
            reg_mosi.data    <= (others => '0');
            reg_mosi.addr    <= (others => '0');
            reg_mosi.rd_wr_n <= '0';
            reg_mosi.valid   <= '0';   
            tp_ext_blank_n   <= '0';
            int_pps          <= '0';
            ext_pps_present  <= '0';            
            log(ID_SEQUENCER_SUB, "All inputs set passive", C_SCOPE);
        end;
        
        -- Overloads for PIF BFMs for register interface
        procedure write(
            constant addr_value   : in std_logic_vector;
            constant data_value   : in std_logic_vector;
            constant msg          : in string;
            constant reg_config   : in t_reg_config := C_REG_CONFIG_DEFAULT) is
        begin
            reg_write(addr_value, data_value, msg, reg_clk, reg_mosi.addr, reg_mosi.data, 
                      reg_mosi.rd_wr_n, reg_mosi.valid, reg_miso.ack, C_CLK_PERIOD, C_SCOPE, shared_msg_id_panel, reg_config);
        end;
        
        procedure read(
            constant addr_value   : in std_logic_vector;
            variable data_value   : out std_logic_vector;
            constant msg          : in string) is
        begin
            reg_read(addr_value, data_value, msg, reg_clk, reg_mosi.addr, reg_mosi.rd_wr_n, reg_mosi.valid, 
                     reg_miso.data, reg_miso.ack,  C_CLK_PERIOD, C_SCOPE);
        end;

        procedure check(
            constant addr_value   : in std_logic_vector;
            constant data_exp     : in std_logic_vector;
            constant alert_level  : in t_alert_level;
            constant msg          : in string) is
        begin
            reg_check(addr_value, data_exp, alert_level, msg, reg_clk, reg_mosi.addr, reg_mosi.rd_wr_n, 
                      reg_mosi.valid, reg_miso.data, reg_miso.ack,  C_CLK_PERIOD, C_SCOPE);
        end;

    begin

        -- Print the configuration to the log
        report_global_ctrl(VOID);
        report_msg_id_panel(VOID);

        enable_log_msg(ALL_MESSAGES);

        log(ID_LOG_HDR, "Start Simulation of TB for timing_protocol", C_SCOPE);
        ------------------------------------------------------------
        set_inputs_passive(VOID);
        clock_ena <= true;   -- to start clock generator
        pulse(reg_srst, reg_clk, 10, "Pulsed reset-signal - active for 10T");

        log(ID_LOG_HDR, "Check defaults on output ports", C_SCOPE);
        ------------------------------------------------------------
        check_value(reg_miso.ack,          '0', ERROR, "Register master-out, slave-in ack default");
        check_value(reg_miso.data, x"00000000", ERROR, "Register master-out, slave-in data default");        
        check_value(tp_async_blank_n,      '1', ERROR, "tp_async_blank_n default");
        check_value(tp_sync_en,            '0', ERROR, "tp_sync_en default");
        
        wait for 1 us;
    
        log(ID_LOG_HDR, "Check register defaults", C_SCOPE);
        ------------------------------------------------------------
        for i in 1 to 16 loop
            check(C_TP_TRANSITION(i), x"00000000", ERROR, "TP Transition Register default");
        end loop;
        check(C_TP_CONTROL,  x"00000000", ERROR, "TP Control Register default");
        check(C_TP_HOLDOVER, x"0000001E", ERROR, "TP Holdover Register default");

        log(ID_LOG_HDR, "Register read/write tests", C_SCOPE);
        ------------------------------------------------------------
        for i in 1 to 16 loop
            write(C_TP_TRANSITION(i), x"FFFFFFFF", "TP Transition Register");
            check(C_TP_TRANSITION(i), x"00FFFFFF", ERROR, "TP Transition Register");
            write(C_TP_TRANSITION(i), x"AAAAAAAA", "TP Transition Register");
            check(C_TP_TRANSITION(i), x"00AAAAAA", ERROR, "TP Transition Register");
            write(C_TP_TRANSITION(i), x"55555555", "TP Transition Register");
            check(C_TP_TRANSITION(i), x"00555555", ERROR, "TP Transition Register");            
            for j in 1 to 16 loop
                if i /= j then
                    check(C_TP_TRANSITION(j), x"00000000", ERROR, "TP Transition Register");
                end if;
            end loop;
            write(C_TP_TRANSITION(i), x"00000000", "TP Transition Register");
        end loop;
        
        write(C_TP_CONTROL, x"FFFFFFFF", "TP Control Register");
        check(C_TP_CONTROL, x"000000FF", ERROR, "TP Control Register");
        write(C_TP_CONTROL, x"AAAAAAAA", "TP Control Register");
        check(C_TP_CONTROL, x"000000AA", ERROR, "TP Control Register");
        write(C_TP_CONTROL, x"55555555", "TP Control Register");
        check(C_TP_CONTROL, x"00000055", ERROR, "TP Control Register");
        
        write(C_TP_HOLDOVER, x"FFFFFFFF", "TP Holdover Register");
        check(C_TP_HOLDOVER, x"0000FFFF", ERROR, "TP Holdover Register");
        write(C_TP_HOLDOVER, x"AAAAAAAA", "TP Holdover Register");
        check(C_TP_HOLDOVER, x"0000AAAA", ERROR, "TP Holdover Register");
        write(C_TP_HOLDOVER, x"55555555", "TP Holdover Register");
        check(C_TP_HOLDOVER, x"00005555", ERROR, "TP Holdover Register");
        
        log(ID_LOG_HDR, "Check mode control", C_SCOPE);
        ------------------------------------------------------------
        -- Set controller to mode 0
        write(C_TP_CONTROL, x"00000000", "TP Control: Mode 0");
        wait for 1 ms + C_CLK_PERIOD;
        check_stable(tp_async_blank_n, 1 ms, ERROR, "Mode 0: TP async blanking stable");
        check_value(       tp_sync_en,  '0', ERROR, "Mode 0: TP sync not enabled");
        
        -- Set controller to mode 0x01
        write(C_TP_CONTROL, x"00000001", "TP Control: Mode 1");
        --pulse(int_pps, reg_clk, 1, "Pulse 1PPS for 1 clock");
        wait for C_CLK_PERIOD*2;
        check_value(tp_async_blank_n, '0', ERROR, "Mode 1: Expect async blank low");
        check_value(      tp_sync_en, '0', ERROR, "Mode 1: TP sync not enabled");
        
        -- Set controller to mode 0x02
        write(C_TP_CONTROL, x"00000002", "TP Control: Mode 2");
        wait for 1 ms + (2*C_CLK_PERIOD);
        check_stable(tp_async_blank_n, 1 ms, ERROR, "Mode 2: TP async blanking stable");
        check_value(       tp_sync_en,  '1', ERROR, "Mode 2: TP sync enabled");
        
        log(ID_LOG_HDR, "Asynchronous mode test, 3 transitions, first async period = blank", C_SCOPE);
        ------------------------------------------------------------
        write(C_TP_TRANSITION(1), x"000000FA", "TP Transition Register 1");     --   25 µs
        write(C_TP_TRANSITION(2), x"00001482", "TP Transition Register 2");     --  525 µs
        write(C_TP_TRANSITION(3), x"000018CE", "TP Transition Register 3");     --  635 µs
        write(C_TP_CONTROL, x"00000021", "TP Control: Mode 1, 3 transitions, first async period = blank");
        
        -- Expect blanking to be low (active) and stable until 1PPS is pushed in        
        wait for 1 ms + (2*C_CLK_PERIOD);
        check_value( tp_async_blank_n,  '0', ERROR, "Blank out before first int. 1PPS");
        check_stable(tp_async_blank_n, 1 ms, ERROR, "Blank out before first int. 1PPS");
        
        -- Trigger internal 1PPS
        pulse(int_pps, reg_clk, 1, "Pulse 1PPS for 1 clock");        
        wait for C_CLK_PERIOD/2;
        
        -- Check the blanking pattern for 10 reps
        for i in 1 to 10 loop
            await_value(tp_async_blank_n, '1',  25000 ns,  25001 ns, ERROR, "Blanking: high after 25 us");
            await_value(tp_async_blank_n, '0', 500000 ns, 500001 ns, ERROR, "Blanking: low after 500 us");
            wait for 110 us;
        end loop;
        
        write(C_TP_CONTROL, x"00000000", "TP Control: Disabled");

        log(ID_LOG_HDR, "Asynchronous mode test, 4 transitions, first async period = blank", C_SCOPE);
        ------------------------------------------------------------
        write(C_TP_TRANSITION(1), x"000000FA", "TP Transition Register 1");     --   25 µs
        write(C_TP_TRANSITION(2), x"00001482", "TP Transition Register 2");     --  525 µs
        write(C_TP_TRANSITION(3), x"000018CE", "TP Transition Register 3");     --  635 µs
        write(C_TP_TRANSITION(4), x"00002710", "TP Transition Register 4");     -- 1000 µs
        write(C_TP_CONTROL, x"00000031", "TP Control: Mode 1, 4 transitions, first async period = blank");
        
        -- Expect blanking to be high (not blanked) and stable until 1PPS is pushed in        
        wait for 1 ms + (2*C_CLK_PERIOD);
        check_value( tp_async_blank_n,  '0', ERROR, "Blank out before first int. 1PPS");
        check_stable(tp_async_blank_n, 1 ms, ERROR, "Blank out before first int. 1PPS");
        
        -- Trigger internal 1PPS
        pulse(int_pps, reg_clk, 1, "Pulse 1PPS for 1 clock");        
        wait for C_CLK_PERIOD/2;
        
        -- Check the blanking pattern for 10 reps
        for i in 1 to 10 loop
            await_value(tp_async_blank_n, '1',  25000 ns,  25001 ns, ERROR, "Blanking: high after 25 us");
            await_value(tp_async_blank_n, '0', 500000 ns, 500001 ns, ERROR, "Blanking: low after 500 us");
            await_value(tp_async_blank_n, '1', 110000 ns, 110001 ns, ERROR, "Blanking: high after 110 us");
            await_value(tp_async_blank_n, '0', 365000 ns, 365001 ns, ERROR, "Blanking: low after 365 us");
        end loop;
        
        log(ID_LOG_HDR, "Asynchronous mode test, 4 transitions, first async period = active", C_SCOPE);
        ------------------------------------------------------------
        write(C_TP_CONTROL, x"00000000", "TP Control: Mode 0 (disabled)");
        write(C_TP_CONTROL, x"00000035", "TP Control: Mode 1 (async), 4 transitions, first async period = active");
        wait for C_CLK_PERIOD;
        
        -- Trigger internal 1PPS
        pulse(int_pps, reg_clk, 1, "Pulse 1PPS for 1 clock");
        
        await_value(tp_async_blank_n, '1', 0 ns, C_CLK_PERIOD*2, ERROR, "Blanking: high after less than 2T");

        -- Check the blanking pattern for 10 reps
        for i in 1 to 10 loop                        
            await_value(tp_async_blank_n, '0',  25000 ns,  25001 ns, ERROR, "Blanking: low after 25 us");
            await_value(tp_async_blank_n, '1', 500000 ns, 500001 ns, ERROR, "Blanking: high after 500 us");
            await_value(tp_async_blank_n, '0', 110000 ns, 110001 ns, ERROR, "Blanking: low after 110 us");
            await_value(tp_async_blank_n, '1', 365000 ns, 365001 ns, ERROR, "Blanking: high after 365 us");
        end loop;
        
        log(ID_LOG_HDR, "Asynchronous mode test, 16 transitions, first async period = blank", C_SCOPE);
        ------------------------------------------------------------
        write(C_TP_TRANSITION(1),  x"000000FA", "TP Transition Register 1");     --  25.0 µs
        write(C_TP_TRANSITION(2),  x"000001F4", "TP Transition Register 2");     --  50.0 µs
        write(C_TP_TRANSITION(3),  x"000002EE", "TP Transition Register 3");     --  75.0 µs
        write(C_TP_TRANSITION(4),  x"000003E8", "TP Transition Register 4");     -- 100.0 µs
        write(C_TP_TRANSITION(5),  x"000003F3", "TP Transition Register 5");     -- 101.1 µs
        write(C_TP_TRANSITION(6),  x"000003F4", "TP Transition Register 6");     -- 101.2 µs
        write(C_TP_TRANSITION(7),  x"000003F5", "TP Transition Register 7");     -- 101.3 µs
        write(C_TP_TRANSITION(8),  x"000003F6", "TP Transition Register 8");     -- 101.4 µs
        write(C_TP_TRANSITION(9),  x"000003F7", "TP Transition Register 9");     -- 101.5 µs
        write(C_TP_TRANSITION(10), x"000003F8", "TP Transition Register 10");    -- 101.6 µs
        write(C_TP_TRANSITION(11), x"000003F9", "TP Transition Register 11");    -- 101.7 µs
        write(C_TP_TRANSITION(12), x"000003FA", "TP Transition Register 12");    -- 101.8 µs
        write(C_TP_TRANSITION(13), x"000003FB", "TP Transition Register 13");    -- 101.9 µs
        write(C_TP_TRANSITION(14), x"000003FC", "TP Transition Register 14");    -- 102.0 µs
        write(C_TP_TRANSITION(15), x"000006F4", "TP Transition Register 15");    -- 178.0 µs
        write(C_TP_TRANSITION(16), x"000009C4", "TP Transition Register 16");    -- 250.0 µs
        write(C_TP_CONTROL, x"000000F1", "TP Control: Mode 1, 16 transitions, first async period = blank");
               
        -- Trigger internal 1PPS
        pulse(int_pps, reg_clk, 1, "Pulse 1PPS for 1 clock");   
        
        await_value(tp_async_blank_n, '0', 0 ns, C_CLK_PERIOD*2, ERROR, "Blanking: low after less than 2T");
        
        -- Check the blanking pattern for 2 reps
        for i in 1 to 2 loop
            await_value(tp_async_blank_n, '1',  25000 ns, 25001 ns, ERROR, "Blanking: high after 25 us");
            await_value(tp_async_blank_n, '0',  25000 ns, 25001 ns, ERROR, "Blanking: low after 25 us");
            await_value(tp_async_blank_n, '1',  25000 ns, 25001 ns, ERROR, "Blanking: high after 25 us");
            await_value(tp_async_blank_n, '0',  25000 ns, 25001 ns, ERROR, "Blanking: low after 25 us");
            await_value(tp_async_blank_n, '1',   1100 ns,  1101 ns, ERROR, "Blanking: high after 1.1 us");
            await_value(tp_async_blank_n, '0',    100 ns,   101 ns, ERROR, "Blanking: low after 0.1 us");
            await_value(tp_async_blank_n, '1',    100 ns,   101 ns, ERROR, "Blanking: high after 0.1 us");
            await_value(tp_async_blank_n, '0',    100 ns,   101 ns, ERROR, "Blanking: low after 0.1 us");
            await_value(tp_async_blank_n, '1',    100 ns,   101 ns, ERROR, "Blanking: high after 0.1 us");
            await_value(tp_async_blank_n, '0',    100 ns,   101 ns, ERROR, "Blanking: low after 0.1 us");
            await_value(tp_async_blank_n, '1',    100 ns,   101 ns, ERROR, "Blanking: high after 0.1 us");
            await_value(tp_async_blank_n, '0',    100 ns,   101 ns, ERROR, "Blanking: low after 0.1 us");
            await_value(tp_async_blank_n, '1',    100 ns,   101 ns, ERROR, "Blanking: high after 0.1 us");
            await_value(tp_async_blank_n, '0',    100 ns,   101 ns, ERROR, "Blanking: low after 0.1 us");
            await_value(tp_async_blank_n, '1',  76000 ns, 76001 ns, ERROR, "Blanking: high after 76 us");
            await_value(tp_async_blank_n, '0',  72000 ns, 72001 ns, ERROR, "Blanking: low after 72 us");
        end loop;
        
        -- Disable TP
        write(C_TP_CONTROL, x"00000000", "TP Control: Mode 0");
        
        log(ID_LOG_HDR, "Transition at zero test", C_SCOPE);
        ------------------------------------------------------------
        write(C_TP_TRANSITION(1),  x"00000000", "TP Transition Register 1");     --  0.0 µs
        write(C_TP_TRANSITION(2),  x"000003E3", "TP Transition Register 2");     --  99.5 µs
        write(C_TP_TRANSITION(3),  x"000003E8", "TP Transition Register 3");     --  100.0 µs
        write(C_TP_CONTROL, x"00000025", "TP Control: Mode 1, 3 transitions, first async period = active");
        
        -- Trigger internal 1PPS
        pulse(int_pps, reg_clk, 1, "Pulse 1PPS for 1 clock");   
        
        await_value(tp_async_blank_n, '0',      0 ns, C_CLK_PERIOD, ERROR, "Blanking: low within 1 clock period");
        await_value(tp_async_blank_n, '1',  99500 ns, 99550 ns,     ERROR, "Blanking: high after 99.5 us");
        await_value(tp_async_blank_n, '0',    500 ns,   501 ns,     ERROR, "Blanking: low after 0.5 us");
        
        -- Check the blanking pattern for 5 more reps
        for i in 1 to 5 loop
            await_value(tp_async_blank_n, '1',  99500 ns, 99501 ns, ERROR, "Blanking: high after 99.5 us");
            await_value(tp_async_blank_n, '0',    500 ns,   501 ns, ERROR, "Blanking: low after 0.5 us");
        end loop;
        
        -- Disable TP
        write(C_TP_CONTROL, x"00000000", "TP Control: Mode 0");
        
        log(ID_LOG_HDR, "Sync loss test - 50 second holdover", C_SCOPE);
        ------------------------------------------------------------
        write(C_TP_TRANSITION(1),  x"00000001", "TP Transition Register 1");     --  0.1 µs
        write(C_TP_TRANSITION(2),  x"00000002", "TP Transition Register 2");     --  0.2 µs
        write(C_TP_CONTROL,        x"00000019", "TP Control: Mode 1, 2 transitions, first async period = blank, blank on sync loss");
        write(C_TP_HOLDOVER,       x"00000032", "TP Holdover: 50 seconds");
        
        -- Trigger internal 1PPS
        pulse(int_pps, reg_clk, 1, "Pulse 1PPS for 1 clock");
        
        -- Expect blanking to be low (active) and stable as Ext. 1PPS is not present
        wait for 1 us;
        check_value( tp_async_blank_n,  '0', ERROR, "Blank out with no sync");
        check_stable(tp_async_blank_n, 1 us, ERROR, "Blank out with no sync");
        
        -- Indicate that external 1PPS is present
        ext_pps_present <= '1' ;
        
        -- Trigger internal 1PPS
        pulse(int_pps, reg_clk, 1, "Pulse 1PPS for 1 clock");
        await_change(tp_async_blank_n, 0 ns, 200 ns, ERROR, "Expect async blank to change");
        
        -- Indicate that external 1PPS is no longer present
        ext_pps_present <= '0' ;

        -- Note that the sync loss counter counts seconds using the internal 1PPS pulses.
        -- To speed the test case up, the pulses are asserted at a faster rate.        
        for i in 1 to 50 loop
            wait for 100 us;
            -- Trigger internal 1PPS
            pulse(int_pps, reg_clk, 1, "Pulse 1PPS for 1 clock");
            await_change(tp_async_blank_n, 0 ns, 200 ns, ERROR, "Expect async blank to change");            
        end loop;
        
        wait for 10 us;
        -- Trigger 51st internal 1PPS
        pulse(int_pps, reg_clk, 1, "Pulse 1PPS for 1 clock");
        
        -- Expect blanking to be low (active) and stable as holdover time has expired
        wait for 1 us + C_CLK_PERIOD;
        check_value( tp_async_blank_n,  '0', ERROR, "Blank out with no sync");
        check_stable(tp_async_blank_n, 1 us, ERROR, "Blank out with no sync");
        
        log(ID_LOG_HDR, "Sync loss test - 0 second holdover", C_SCOPE);
        ------------------------------------------------------------
        write(C_TP_HOLDOVER,       x"00000000", "TP Holdover: 0 seconds");
        
        -- Indicate that external 1PPS is present
        ext_pps_present <= '1' ;
        
        -- Trigger internal 1PPS
        pulse(int_pps, reg_clk, 1, "Pulse 1PPS for 1 clock");
        await_change(tp_async_blank_n, 0 ns, 200 ns, ERROR, "Expect async blank to change");
        
        -- Indicate that external 1PPS is no longer present
        ext_pps_present <= '0' ;
        
        -- Trigger internal 1PPS
        pulse(int_pps, reg_clk, 1, "Pulse 1PPS for 1 clock");
        
        -- Expect blanking to be low (active) and stable as holdover time has expired
        wait for 1 us + C_CLK_PERIOD;
        check_value( tp_async_blank_n,  '0', ERROR, "Blank out with no sync");
        check_stable(tp_async_blank_n, 1 us, ERROR, "Blank out with no sync");
        
        log(ID_LOG_HDR, "Sync loss test - 65,535 second holdover", C_SCOPE);
        ------------------------------------------------------------
        write(C_TP_HOLDOVER,       x"0000FFFF", "TP Holdover: 65,535 seconds");
        
        -- Indicate that external 1PPS is present
        ext_pps_present <= '1' ;
        
        -- Trigger internal 1PPS
        pulse(int_pps, reg_clk, 1, "Pulse 1PPS for 1 clock");
        await_change(tp_async_blank_n, 0 ns, 200 ns, ERROR, "Expect async blank to change");
        
        -- Indicate that external 1PPS is no longer present
        ext_pps_present <= '0' ;
        
                -- Indicate that external 1PPS is no longer present
        ext_pps_present <= '0' ;

        -- Note that the sync loss counter counts seconds using the internal 1PPS pulses.
        -- To speed the test case up, the pulses are asserted at a faster rate, even faster this time
        -- as there are 65,535 pulses to get through
        for i in 1 to 65535 loop
            wait for 1 us;
            -- Trigger internal 1PPS
            pulse(int_pps, reg_clk, 1, "Pulse 1PPS for 1 clock");
            await_change(tp_async_blank_n, 0 ns, 200 ns, ERROR, "Expect async blank to change");            
        end loop;
        
        wait for 10 us;
        -- Trigger 65,536th internal 1PPS
        pulse(int_pps, reg_clk, 1, "Pulse 1PPS for 1 clock");
        
        -- Expect blanking to be low (active) and stable as holdover time has expired
        wait for 1 us + C_CLK_PERIOD;
        check_value( tp_async_blank_n,  '0', ERROR, "Blank out with no sync");
        check_stable(tp_async_blank_n, 1 us, ERROR, "Blank out with no sync");

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

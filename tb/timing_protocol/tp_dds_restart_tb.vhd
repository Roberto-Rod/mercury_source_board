----------------------------------------------------------------------------------
--! @file tp_dds_restart_tb.vhd
--! @brief Testbench for Timing Protocol DDS line restart command module
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

entity tp_dds_restart_tb is
end tp_dds_restart_tb;

----------------------------------------------------------------------------------
--! @brief Testbench for Timing Protocol DDS line restart command module
----------------------------------------------------------------------------------
architecture tb of tp_dds_restart_tb is
    -- Register Bus
    signal clk                 : std_logic := '0'; --! The clock
    signal srst                : std_logic := '0'; --! Synchronous reset

    -- Blanking Inputs
    signal tp_ext_blank_n      : std_logic;                        --! Masked and synchronised external blanking input
    signal tp_async_blank_n    : std_logic;                        --! Asynchronous Timing Protocol blanking output

    -- DDS Line Restart
    signal dds_restart_prep    : std_logic;                        --! Prepare DDS for line restart
    signal dds_restart_exec    : std_logic;                        --! Execute DDS line restart
    
    -- Clock enable flag and clock period
    signal clock_ena       : boolean := false;
    constant C_CLK_PERIOD  : time    := 12.5 ns;
    
    constant C_DELTA       : time    := 1 ps;
begin
    i_dut: entity work.tp_dds_restart
    port map (
        -- Register Bus
        clk                 => clk,
        srst                => srst,

        -- Blanking Inputs
        tp_ext_blank_n      => tp_ext_blank_n,
        tp_async_blank_n    => tp_async_blank_n,
        
        -- DDS Line Restart
        dds_restart_prep    => dds_restart_prep,
        dds_restart_exec    => dds_restart_exec
    );
    
    -- Set up the clock generator
    clock_gen(clk, clock_ena, C_CLK_PERIOD);
    
    ------------------------------------------------
    -- PROCESS: p_main
    ------------------------------------------------
    p_main: process
        procedure set_inputs_passive(dummy : t_void) is
        begin
            tp_ext_blank_n   <= '1';
            tp_async_blank_n <= '1';
            log(ID_SEQUENCER_SUB, "All inputs set passive", C_SCOPE);
        end;
    begin
        -- Print the configuration to the log
        report_global_ctrl(VOID);
        report_msg_id_panel(VOID);

        enable_log_msg(ALL_MESSAGES);

        log(ID_LOG_HDR, "Start Simulation of TB for tp_dds_restart_tb", C_SCOPE);
        ------------------------------------------------------------
        set_inputs_passive(VOID);
        clock_ena <= true;   -- to start clock generator
        pulse(srst, clk, 10, "Pulsed reset-signal - active for 10T");

        log(ID_LOG_HDR, "Check defaults on output ports", C_SCOPE);
        ------------------------------------------------------------
        check_value(dds_restart_prep, '0', ERROR, "dds_restart_prep default");
        check_value(dds_restart_exec, '0', ERROR, "dds_restart_exec default");
        
        log(ID_LOG_HDR, "External blanking, no TP blanking", C_SCOPE);
        ------------------------------------------------------------
        -- Pulse external blanking for one clock cycle less than 100 µs
        pulse(tp_ext_blank_n, '0', clk, (100 us / C_CLK_PERIOD) - 1, "External blanking - active low for 100 µs minus one clock cycle");
        wait for 100 ns;
        check_stable(dds_restart_prep, 100 us, ERROR, "dds_restart_prep should not have changed");
        check_stable(dds_restart_exec, 100 us, ERROR, "dds_restart_exec should not have changed");
        
        -- Pulse external blanking for 100 µs
        pulse(tp_ext_blank_n, '0', clk, 100 us / C_CLK_PERIOD, "External blanking - active low for 100 µs");        
        check_stable(dds_restart_prep, 100 us, ERROR, "dds_restart_prep should not have changed during blank period");
        await_value(dds_restart_prep, '1', 0 ns,         C_CLK_PERIOD,         ERROR, "dds_restart_prep should transition high");
        await_value(dds_restart_exec, '1', C_CLK_PERIOD, C_CLK_PERIOD+C_DELTA, ERROR, "dds_restart_exec should transition high");
        
        -- Pulse external blanking for 200 µs
        tp_ext_blank_n <= '0';
        wait for 100 us;
        await_value(dds_restart_prep, '1', 0 ns, C_CLK_PERIOD+C_DELTA, ERROR, "dds_restart_prep should transition high");
        wait for 100 us;
        tp_ext_blank_n <= '1';
        check_stable(dds_restart_prep, 100 us, ERROR, "dds_restart_prep should have stayed high");
        check_stable(dds_restart_exec, 200 us, ERROR, "dds_restart_prep should have stayed low");
        await_value(dds_restart_prep, '0', 0 ns, C_CLK_PERIOD+C_DELTA, ERROR, "dds_restart_prep should transition low");
        await_value(dds_restart_exec, '1', 0 ns, C_CLK_PERIOD+C_DELTA, ERROR, "dds_restart_exec should transition high");

        log(ID_LOG_HDR, "TP blanking, no external blanking", C_SCOPE);
        ------------------------------------------------------------
        -- Assert TP blanking for 1 clock cycle (less than resolution or min. allowed window)        
        pulse(tp_async_blank_n, '0', clk, 1, "TP blanking - active low for 1 clock cycle");
        await_value(dds_restart_prep, '1', 0 ns,         C_CLK_PERIOD,         ERROR, "dds_restart_prep should transition high");
        await_value(dds_restart_exec, '1', C_CLK_PERIOD, C_CLK_PERIOD+C_DELTA, ERROR, "dds_restart_exec should transition high");
        
        wait for C_CLK_PERIOD;
        
        -- Assert TP blanking for 0.1 µs (TP resolution)
        pulse(tp_async_blank_n, '0', clk, 0.1 us / C_CLK_PERIOD, "TP blanking - active low for 0.1 us");
        check_value(dds_restart_prep, '1', ERROR, "dds_restart_prep should be high");
        check_value(dds_restart_exec, '0', ERROR, "dds_restart_exec should be low");
        check_stable(dds_restart_prep,  75 ns, ERROR, "dds_restart_prep should have stayed high");
        check_stable(dds_restart_exec, 100 ns, ERROR, "dds_restart_exec should have stayed low");
        await_value(dds_restart_exec, '1', C_CLK_PERIOD, 2*C_CLK_PERIOD+C_DELTA, ERROR, "dds_restart_exec should transition high");
        
        wait for C_CLK_PERIOD;
        
        -- Assert TP blanking for 0.5 µs (min. allowed TP window)
        pulse(tp_async_blank_n, '0', clk, 0.5 us / C_CLK_PERIOD, "TP blanking - active low for 0.5 us");
        check_value(dds_restart_prep, '1', ERROR, "dds_restart_prep should be high");
        check_value(dds_restart_exec, '0', ERROR, "dds_restart_exec should be low");
        check_stable(dds_restart_prep, 475 ns, ERROR, "dds_restart_prep should have stayed high");
        check_stable(dds_restart_exec, 500 ns, ERROR, "dds_restart_exec should have stayed low");
        await_value(dds_restart_exec, '1', C_CLK_PERIOD, 2*C_CLK_PERIOD+C_DELTA, ERROR, "dds_restart_exec should transition high");
                
        wait for C_CLK_PERIOD;
        
        -- Assert TP blanking for 100 µs (realistic value)
        pulse(tp_async_blank_n, '0', clk, 100 us / C_CLK_PERIOD, "TP blanking - active low for 100 us");
        check_value(dds_restart_prep, '1', ERROR, "dds_restart_prep should be high");
        check_value(dds_restart_exec, '0', ERROR, "dds_restart_exec should be low");
        check_stable(dds_restart_prep,  99975 ns, ERROR, "dds_restart_prep should have stayed high");
        check_stable(dds_restart_exec, 100000 ns, ERROR, "dds_restart_exec should have stayed low");
        await_value(dds_restart_exec, '1', C_CLK_PERIOD, 2*C_CLK_PERIOD+C_DELTA, ERROR, "dds_restart_exec should transition high");        
        
        wait for C_CLK_PERIOD;
        
        log(ID_LOG_HDR, "External blanking & TP blanking, overlap, ext. asserts first, ext. de-asserts first", C_SCOPE);
        ------------------------------------------------------------
        tp_ext_blank_n   <= '0';        
        wait for 100 us;
        check_value(dds_restart_prep, '0', ERROR, "dds_restart_prep should be low");
        wait for 10 us;
        check_value(dds_restart_prep, '1', ERROR, "dds_restart_prep should be high");
        tp_async_blank_n <= '0';
        wait for 100 us;
        tp_ext_blank_n   <= '1';     
        wait for 10 us;
        tp_async_blank_n <= '1';
        check_value(dds_restart_exec, '0', ERROR, "dds_restart_exec should be low");
        check_value(dds_restart_prep, '1', ERROR, "dds_restart_prep should be high");
        check_stable(dds_restart_exec, 220000 ns, ERROR, "dds_restart_exec should have stayed low");
        check_stable(dds_restart_prep, 110000 ns, ERROR, "dds_restart_prep should have stayed high");
        await_value(dds_restart_exec, '1', C_CLK_PERIOD, 2*C_CLK_PERIOD+C_DELTA, ERROR, "dds_restart_exec should transition high");   

        wait for C_CLK_PERIOD;       
        
        log(ID_LOG_HDR, "External blanking & TP blanking, overlap, ext. asserts first, TP de-asserts first", C_SCOPE);
        ------------------------------------------------------------
        tp_ext_blank_n   <= '0';        
        wait for 100 us;
        check_value(dds_restart_prep, '0', ERROR, "dds_restart_prep should be low");
        wait for 10 us;
        check_value(dds_restart_prep, '1', ERROR, "dds_restart_prep should be high");
        tp_async_blank_n <= '0';
        wait for 100 us;
        tp_async_blank_n <= '1';
        wait for 10 us;
        tp_ext_blank_n   <= '1';
        
        check_value(dds_restart_exec, '0', ERROR, "dds_restart_exec should be low");
        check_value(dds_restart_prep, '1', ERROR, "dds_restart_prep should be high");
        check_stable(dds_restart_exec, 220000 ns, ERROR, "dds_restart_exec should have stayed low");
        check_stable(dds_restart_prep, 110000 ns, ERROR, "dds_restart_prep should have stayed high");
        await_value(dds_restart_exec, '1', C_CLK_PERIOD, 2*C_CLK_PERIOD+C_DELTA, ERROR, "dds_restart_exec should transition high");   
        
        wait for C_CLK_PERIOD;
        
        log(ID_LOG_HDR, "External blanking & TP blanking, overlap, TP asserts first, ext. de-asserts first", C_SCOPE);
        ------------------------------------------------------------
        tp_async_blank_n <= '0';
        wait for 1 us;
        check_value(dds_restart_prep, '1', ERROR, "dds_restart_prep should be high");        
        tp_ext_blank_n   <= '0';        
        wait for 100 us;
        tp_ext_blank_n   <= '1';     
        wait for 10 us;
        tp_async_blank_n <= '1';
        check_value(dds_restart_exec, '0', ERROR, "dds_restart_exec should be low");
        check_value(dds_restart_prep, '1', ERROR, "dds_restart_prep should be high");
        check_stable(dds_restart_exec, 111000 ns, ERROR, "dds_restart_exec should have stayed low");
        check_stable(dds_restart_prep, 110000 ns, ERROR, "dds_restart_prep should have stayed high");
        await_value(dds_restart_exec, '1', C_CLK_PERIOD, 2*C_CLK_PERIOD+C_DELTA, ERROR, "dds_restart_exec should transition high");   

        wait for C_CLK_PERIOD;  
        
        log(ID_LOG_HDR, "External blanking & TP blanking, overlap, TP asserts first, TP de-asserts first", C_SCOPE);
        ------------------------------------------------------------
        tp_async_blank_n <= '0';
        wait for 1 us;
        check_value(dds_restart_prep, '1', ERROR, "dds_restart_prep should be high");        
        tp_ext_blank_n   <= '0';        
        wait for 100 us;
        tp_async_blank_n <= '1';
        wait for 10 us;
        tp_ext_blank_n   <= '1';
        
        check_value(dds_restart_exec, '0', ERROR, "dds_restart_exec should be low");
        check_value(dds_restart_prep, '1', ERROR, "dds_restart_prep should be high");
        check_stable(dds_restart_exec, 111000 ns, ERROR, "dds_restart_exec should have stayed low");
        check_stable(dds_restart_prep, 110000 ns, ERROR, "dds_restart_prep should have stayed high");
        await_value(dds_restart_exec, '1', C_CLK_PERIOD, 2*C_CLK_PERIOD+C_DELTA, ERROR, "dds_restart_exec should transition high");   

        wait for C_CLK_PERIOD;
        
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

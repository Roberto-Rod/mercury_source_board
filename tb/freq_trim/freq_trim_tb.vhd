----------------------------------------------------------------------------------
--! @file freq_trim_tb.vhd
--! @brief Testbench for Frequency Trimming module
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

entity freq_trim_tb is
end freq_trim_tb;

----------------------------------------------------------------------------------
--! @brief Testbench for Timing Protocol module
----------------------------------------------------------------------------------
architecture tb of freq_trim_tb is
    -- Bit-widths 
    constant C_CLK_CNT_BITS    : integer := 27;
    
    -- Register Bus
    signal reg_clk_i           : std_logic := '0'; --! The register clock
    signal reg_srst_i          : std_logic := '0'; --! Register synchronous reset
    signal reg_mosi_i          : reg_mosi_type;    --! Register master-out, slave-in signals
    signal reg_miso_o          : reg_miso_type;    --! Register master-in, slave-out signals

    -- Frequency error
    signal clk_count_i         : std_logic_vector(C_CLK_CNT_BITS-1 downto 0); --! Clock count (80 MHz clock)
    signal clk_count_valid_i   : std_logic;
    
    -- VC-TCXO Control
    signal dac_val_o           : std_logic_vector(11 downto 0);            --! DAC value out, 12-bit unsigned, volts = val/1000
    signal dac_val_valid_o     : std_logic;
    
    -- Clock enable flag and clock period
    signal clock_ena       : boolean := false;
    constant C_CLK_PERIOD  : time    := 12.5 ns;
begin
    i_dut: entity work.freq_trim
    generic map (
        CLK_CNT_BITS        => C_CLK_CNT_BITS
    )
    port map (
        -- Register Bus
        reg_clk_i           => reg_clk_i,
        reg_srst_i          => reg_srst_i,
        reg_mosi_i          => reg_mosi_i,
        reg_miso_o          => reg_miso_o,

        -- Frequency error
        clk_count_i         => clk_count_i,
        clk_count_valid_i   => clk_count_valid_i,
        
        -- VC-TCXO Control
        dac_val_o           => dac_val_o,
        dac_val_valid_o     => dac_val_valid_o
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
        constant C_TRIM_CTRL   : std_logic_vector(23 downto 0) := x"000010";
        constant C_TRIM_ERR    : std_logic_vector(23 downto 0) := x"000011";
        constant C_TRIM_ACC    : std_logic_vector(23 downto 0) := x"000012";
        constant C_TRIM_MULT_O : std_logic_vector(23 downto 0) := x"000013";
        
        -- TCXO sensitivity and offset variable
        constant C_TCXO_SENSITIVITY : integer := 1; -- Hz per DAC LSB
        variable tcxo_offs          : integer;
        
        procedure set_inputs_passive(dummy : t_void) is
        begin
            reg_mosi_i.data    <= (others => '0');
            reg_mosi_i.addr    <= (others => '0');
            reg_mosi_i.rd_wr_n <= '0';
            reg_mosi_i.valid   <= '0';   
            clk_count_i        <= (others => '0');
            clk_count_valid_i  <= '0';
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
        check_value(dac_val_valid_o,         '0', ERROR, "dac_val_valid_o default");
        
        wait for 1 us;
    
        log(ID_LOG_HDR, "Check register defaults", C_SCOPE);
        ------------------------------------------------------------
        check(C_TRIM_CTRL, x"000007D0", ERROR, "Trim Control Register default");
        
        log(ID_LOG_HDR, "Enable trimming", C_SCOPE);
        ------------------------------------------------------------
        write(C_TRIM_CTRL, x"800007D0", "Enable frequency trimming");
        
        -- Wait after enabling
        wait for 1 us;
        
        -- Push a clock count in which is 800 under expected (to match Octave simulation)
        clk_count_i <= std_logic_vector(to_unsigned(80e6-800, clk_count_i'length));
        pulse(clk_count_valid_i, reg_clk_i, 1, "Pulse clock count valid for 1T");

        -- First count should be ignored so push the same one in again
        wait for 200 ns;
        pulse(clk_count_valid_i, reg_clk_i, 1, "Pulse clock count valid for 1T");
                
        -- Check that loop values match Octave simulation
        wait for 200 ns;
        check(C_TRIM_ERR,    x"00000320", ERROR, "Trim error");
        check(C_TRIM_ACC,    x"00034EE0", ERROR, "Trim accumulator");
        check(C_TRIM_MULT_O, x"00000676", ERROR, "Trim multiplier output");
        
        -- Push the next error value in
        clk_count_i <= std_logic_vector(to_unsigned(80e6-776, clk_count_i'length));
        pulse(clk_count_valid_i, reg_clk_i, 1, "Pulse clock count valid for 1T");
        
        -- Check that loop values match Octave simulation
        wait for 200 ns;
        check(C_TRIM_ERR,    x"00000308", ERROR, "Trim error");
        check(C_TRIM_ACC,    x"000351E8", ERROR, "Trim accumulator");
        check(C_TRIM_MULT_O, x"0000067B", ERROR, "Trim multiplier output");
        
        -- Now put a zero count in multiple times to check the limiters
        clk_count_i <= (others => '0');        
        for i in 1 to 100 loop
            pulse(clk_count_valid_i, reg_clk_i, 1, "Pulse clock count valid for 1T");
            wait for 1 us;
        end loop;
        
        check(C_TRIM_ERR,    x"00000FFF", ERROR, "Trim error");
        check(C_TRIM_ACC,    x"0007FFFF", ERROR, "Trim accumulator");
        check(C_TRIM_MULT_O, x"00000F9F", ERROR, "Trim multiplier output");
        
        -- Now put a full-scale count in multiple times to check the limiters in the other direction
        clk_count_i <= (others => '1');        
        for i in 1 to 200 loop            
            pulse(clk_count_valid_i, reg_clk_i, 1, "Pulse clock count valid for 1T");
            wait for 1 us;
        end loop;
        
        check(C_TRIM_ERR,    x"00001000", ERROR, "Trim error");
        check(C_TRIM_ACC,    x"00000000", ERROR, "Trim accumulator");
        check(C_TRIM_MULT_O, x"00000000", ERROR, "Trim multiplier output");
        
        -- Now respond to DAC output
        for i in 1 to 200 loop
            tcxo_offs   := (to_integer(unsigned(dac_val_o)) - 1650) * C_TCXO_SENSITIVITY;
            clk_count_i <= std_logic_vector(to_unsigned(8*(10e6 + tcxo_offs), clk_count_i'length));
            pulse(clk_count_valid_i, reg_clk_i, 1, "Pulse clock count valid for 1T");
            wait until dac_val_valid_o = '1';
        end loop;
        
        check(C_TRIM_ERR,    x"00000000", ERROR, "Trim error");
        check(C_TRIM_ACC,    x"00034CD3", ERROR, "Trim accumulator");
        check(C_TRIM_MULT_O, x"00000672", ERROR, "Trim multiplier output");
        
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

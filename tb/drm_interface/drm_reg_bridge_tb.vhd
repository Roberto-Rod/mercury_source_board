----------------------------------------------------------------------------------
--! @file drm_reg_bridge_tb.vhd
--! @brief Testbench for DRM interface module
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

entity drm_reg_bridge_tb is
end drm_reg_bridge_tb;

----------------------------------------------------------------------------------
--! @brief Testbench for Timing Protocol module
----------------------------------------------------------------------------------
architecture tb of drm_reg_bridge_tb is
    -- Register Bus
    signal reg_clk             : std_logic := '0'; --! The register clock
    signal reg_srst            : std_logic := '0'; --! Register synchronous reset
    signal reg_mosi            : reg_mosi_type;    --! Register master-out, slave-in signals
    signal reg_miso            : reg_miso_type;    --! Register master-in, slave-out signals

    signal reg_mosi_drm        : reg_mosi_type;    --! Register master-out, slave-in signals - master interface
    signal reg_miso_drm        : reg_miso_type;    --! Register master-in, slave-out signals - master interface

    -- Aurora User Clock
    signal user_clk            : std_logic := '0';
    signal link_srst           : std_logic;

    -- LocalLink Tx Interface
    signal tx_d                : std_logic_vector(31 downto 0);
    signal tx_rem              : std_logic_vector(0 to 1);
    signal tx_src_rdy_n        : std_logic;
    signal tx_sof_n            : std_logic;
    signal tx_eof_n            : std_logic;
    signal tx_dst_rdy_n        : std_logic := '0';

    -- LocalLink Rx Interface
    signal rx_d                : std_logic_vector(31 downto 0);
    signal rx_rem              : std_logic_vector(0 to 1);
    signal rx_src_rdy_n        : std_logic;
    signal rx_sof_n            : std_logic;
    signal rx_eof_n            : std_logic;

    -- Clock enable flag and clock period
    signal reg_clock_ena       : boolean := false;
    signal user_clock_ena      : boolean := false;
    constant C_REG_CLK_PERIOD  : time    := 12.5 ns;
    constant C_USER_CLK_PERIOD : time    := 64.0 ns;
begin
    i_dut: entity work.drm_reg_bridge
    port map (
        -- Register Buses
        reg_clk         => reg_clk,
        reg_srst        => reg_srst,
        slv_reg_mosi    => reg_mosi,
        slv_reg_miso    => reg_miso,
        reg_mosi_drm    => reg_mosi_drm,
        reg_miso_drm    => reg_miso_drm,

        -- Aurora User Clock
        user_clk        => user_clk,
        link_srst       => link_srst,

        -- LocalLink Tx Interface
        tx_d            => tx_d,
        tx_rem          => tx_rem,
        tx_src_rdy_n    => tx_src_rdy_n,
        tx_sof_n        => tx_sof_n,
        tx_eof_n        => tx_eof_n,
        tx_dst_rdy_n    => tx_dst_rdy_n,

        -- LocalLink Rx Interface
        rx_d            => rx_d,
        rx_rem          => rx_rem,
        rx_src_rdy_n    => rx_src_rdy_n,
        rx_sof_n        => rx_sof_n,
        rx_eof_n        => rx_eof_n
    );

    i_general_registers: entity work.general_registers
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi_drm,
        reg_miso            => reg_miso_drm,

        -- External GPIO
        ext_gpio            => open,

        -- Hardware version/mod-level
        hw_vers             => "101",
        hw_mod              => "100"
    );

    -- Set up the clock generators
    clock_gen(reg_clk, reg_clock_ena, C_REG_CLK_PERIOD);
    clock_gen(user_clk, user_clock_ena, C_USER_CLK_PERIOD);

    process(tx_d, tx_rem, tx_src_rdy_n, tx_sof_n, tx_eof_n)
    begin
        rx_d         <= tx_d;
        rx_rem       <= tx_rem;
        rx_src_rdy_n <= tx_src_rdy_n;
        rx_sof_n     <= tx_sof_n;
        rx_eof_n     <= tx_eof_n;
    end process;
    
    process(user_clk)
    begin
        if rising_edge(user_clk) then
            tx_dst_rdy_n <= not tx_dst_rdy_n;
        end if;
    end process;

    ------------------------------------------------
    -- PROCESS: p_main
    ------------------------------------------------
    p_main: process        
        constant C_REG_CONFIG : t_reg_config := (max_wait_cycles => 1000,
                                                 max_wait_cycles_severity => FAILURE);

        constant C_REG_CONFIG_NO_RESP : t_reg_config := (max_wait_cycles => 100,
                                                         max_wait_cycles_severity => NO_ALERT);

        -- DRM base address
        constant C_DRM_DWG      : std_logic_vector(23 downto 0) := x"110001";
        constant C_DRM_GPIO     : std_logic_vector(23 downto 0) := x"110003";
        
        procedure set_inputs_passive(dummy : t_void) is
        begin
            reg_srst           <= '0';
            link_srst          <= '0';
            reg_mosi.data      <= (others => '0');
            reg_mosi.addr      <= (others => '0');
            reg_mosi.rd_wr_n   <= '0';
            reg_mosi.valid     <= '0';
            log(ID_SEQUENCER_SUB, "All inputs set passive", C_SCOPE);
        end;

        -- Overloads for PIF BFMs for register interface
        procedure write(
            constant addr_value   : in std_logic_vector;
            constant data_value   : in std_logic_vector;
            constant msg          : in string) is
        begin
            reg_write(addr_value, data_value, msg, reg_clk, reg_mosi.addr, reg_mosi.data,
                      reg_mosi.rd_wr_n, reg_mosi.valid, reg_miso.ack, C_REG_CLK_PERIOD, C_SCOPE, shared_msg_id_panel, C_REG_CONFIG);
        end;

        procedure read(
            constant addr_value   : in std_logic_vector;
            variable data_value   : out std_logic_vector;
            constant msg          : in string;
            constant reg_config   : t_reg_config := C_REG_CONFIG) is
        begin
            reg_read(addr_value, data_value, msg, reg_clk, reg_mosi.addr, reg_mosi.rd_wr_n, reg_mosi.valid,
                     reg_miso.data, reg_miso.ack, C_REG_CLK_PERIOD, C_SCOPE, shared_msg_id_panel, reg_config);
        end;

        procedure check(
            constant addr_value   : in std_logic_vector;
            constant data_exp     : in std_logic_vector;
            constant alert_level  : in t_alert_level;
            constant msg          : in string;
            constant reg_config   : t_reg_config := C_REG_CONFIG) is
        begin
            reg_check(addr_value, data_exp, alert_level, msg, reg_clk, reg_mosi.addr, reg_mosi.rd_wr_n,
                      reg_mosi.valid, reg_miso.data, reg_miso.ack, C_REG_CLK_PERIOD, C_SCOPE, shared_msg_id_panel, reg_config);
        end;

    begin

        -- Print the configuration to the log
        report_global_ctrl(VOID);
        report_msg_id_panel(VOID);

        enable_log_msg(ALL_MESSAGES);

        log(ID_LOG_HDR, "Start Simulation of TB for timing_protocol", C_SCOPE);
        ------------------------------------------------------------
        set_inputs_passive(VOID);
        reg_clock_ena <= true;   -- to start clock generator
        user_clock_ena <= true;
        pulse(reg_srst, reg_clk, 10, "Pulsed reset-signal - active for 10T");
        pulse(link_srst, reg_clk, 10, "Pulsed reset-signal - active for 10T");        

        log(ID_LOG_HDR, "Check defaults on output ports", C_SCOPE);
        ------------------------------------------------------------
        check_value(reg_miso.ack,          '0', ERROR, "Slave: register master-in, slave-out ack default");
        check_value(reg_miso.data, x"00000000", ERROR, "Slave: register master-in, slave-out data default");
        check_value(reg_mosi_drm.valid,   '0', ERROR, "Master: register master-out, slave-in valid default");
        check_value(tx_src_rdy_n,          '1', ERROR, "Transmit source ready default");

        wait for 1 us;

        log(ID_LOG_HDR, "DRM register read/write tests", C_SCOPE);
        ------------------------------------------------------------
        check(C_DRM_DWG, x"05040008", ERROR, "DRM Base Register");
        
        check(x"000000", x"00000000", ERROR, "Read non-DRM register", C_REG_CONFIG_NO_RESP);
        
        check(C_DRM_GPIO, x"00000000", ERROR, "Read DRM GPIO");
        write(C_DRM_GPIO, x"000000AA",        "Write DRM GPIO");
        check(C_DRM_GPIO, x"000000AA", ERROR, "Read DRM GPIO");

        --==================================================================================================
        -- Ending the simulation
        --------------------------------------------------------------------------------------
        wait for 1000 ns;             -- to allow some time for completion
        report_alert_counters(FINAL); -- Report final counters and print conclusion for simulation (Success/Fail)
        log(ID_LOG_HDR, "SIMULATION COMPLETED", C_SCOPE);
        reg_clock_ena <= false;           -- to gracefully stop the simulation - if possible
        user_clock_ena <= false;
        -- Hopefully stops when clock is stopped. Otherwise force a stop.
        assert false
        report "End of simulation.  (***Ignore this failure. Was provoked to stop the simulation.)"
        severity failure;
        wait;  -- to stop completely

    end process p_main;

end tb;

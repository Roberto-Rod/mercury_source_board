library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library uvvm_vvc_framework;
use uvvm_vvc_framework.ti_vvc_framework_support_pkg.all;

library bitvis_vip_reg;
use bitvis_vip_reg.vvc_methods_pkg.all;
use bitvis_vip_reg.td_vvc_framework_common_methods_pkg.all;

-- Test bench entity
entity general_registers_vvc_tb is
end entity;

-- Test bench architecture
architecture func of general_registers_vvc_tb is
    
    constant C_SCOPE              : string  := C_TB_SCOPE_DEFAULT;

    -- Clock period setting
    constant C_CLK_PERIOD : time := 12.5 ns; -- 80 MHz

    -- Predefined register addresses
    constant C_ADDR_DWG_NUMBER    : unsigned(23 downto 0) := x"000001";
    constant C_ADDR_GPIO_DATA     : unsigned(23 downto 0) := x"000002";
    constant C_ADDR_GPIO_DIR      : unsigned(23 downto 0) := x"000003";

    -- Log overload procedure for simplification
    procedure log(msg : string) is
    begin
        log(ID_SEQUENCER, msg, C_SCOPE);
    end;

    begin

    -----------------------------------------------------------------------------
    -- Instantiate test harness, containing DUT and Executors
    -----------------------------------------------------------------------------
    i_test_harness : entity work.general_registers_vvc_th;
 
    ------------------------------------------------
    -- PROCESS: p_main
    ------------------------------------------------
    p_main: process
    begin
        -- Wait for UVVM to finish initialization
        await_uvvm_initialization(VOID);

        -- Print the configuration to the log
        report_global_ctrl(VOID);
        report_msg_id_panel(VOID);

        --enable_log_msg(ALL_MESSAGES);
        disable_log_msg(ALL_MESSAGES);
        enable_log_msg(ID_LOG_HDR);
        enable_log_msg(ID_SEQUENCER);
        enable_log_msg(ID_UVVM_SEND_CMD);

        disable_log_msg(REG_VVCT, 1, ALL_MESSAGES);
        enable_log_msg(REG_VVCT,  1, ID_BFM);
        enable_log_msg(REG_VVCT,  1, ID_FINISH_OR_STOP);

        log(ID_LOG_HDR, "Starting simulation of TB for general_registers using VVCs", C_SCOPE);
        ------------------------------------------------------------

        log("Wait 10 clock period for reset to be turned off");
        wait for (10 * C_CLK_PERIOD); -- for reset to be turned off

        log(ID_LOG_HDR, "Check register defaults ", C_SCOPE);
        ------------------------------------------------------------
        reg_check(REG_VVCT, 1, C_ADDR_DWG_NUMBER, x"02050008", "Drawing number default");
        --reg_check(REG_VVCT, 1, C_ADDR_GPIO_DATA,  x"000000ZZ", "GPIO data default");
        reg_check(REG_VVCT, 1, C_ADDR_GPIO_DIR,   x"00000000", "GPIO direction default");
        await_completion(REG_VVCT, 1, 12 * C_CLK_PERIOD);
        
        log(ID_LOG_HDR, "Write GPIO data", C_SCOPE);
        ------------------------------------------------------------
        reg_write(REG_VVCT, 1, C_ADDR_GPIO_DATA, x"AAAAAAAA", "GPIO data");
        reg_write(REG_VVCT, 1, C_ADDR_GPIO_DIR,  x"FFFFFFFF", "GPIO direction");
        await_completion(REG_VVCT, 1, 8 * C_CLK_PERIOD);
        reg_check(REG_VVCT, 1, C_ADDR_GPIO_DIR,  x"000000FF", "GPIO direction");
        reg_check(REG_VVCT, 1, C_ADDR_GPIO_DATA, x"000000AA", "GPIO data");
        
        -----------------------------------------------------------------------------
        -- Ending the simulation
        -----------------------------------------------------------------------------
        wait for 1000 ns;             -- to allow some time for completion
        report_alert_counters(FINAL); -- Report final counters and print conclusion for simulation (Success/Fail)
        log(ID_LOG_HDR, "SIMULATION COMPLETED", C_SCOPE);

        -- Finish the simulation
        std.env.stop;
        wait;  -- to stop completely

    end process p_main;

end func;

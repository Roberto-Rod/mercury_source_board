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

library bitvis_vip_locallink;
use bitvis_vip_locallink.vvc_methods_pkg.all;
use bitvis_vip_locallink.td_vvc_framework_common_methods_pkg.all;

library drm_interface;
use drm_interface.drm_reg_bridge_vvc_pkg.all;

-- Test bench entity
entity drm_reg_bridge_vvc_tb is
end entity;

-- Test bench architecture
architecture func of drm_reg_bridge_vvc_tb is
    
    constant C_SCOPE              : string  := C_TB_SCOPE_DEFAULT;

    -- Log overload procedure for simplification
    procedure log(msg : string) is
    begin
        log(ID_SEQUENCER, msg, C_SCOPE);
    end;

    begin

    -----------------------------------------------------------------------------
    -- Instantiate test harness, containing DUT and Executors
    -----------------------------------------------------------------------------
    i_test_harness : entity work.drm_reg_bridge_vvc_th;
 
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

        disable_log_msg(REG_VVCT, C_IDX_REG_MASTER, ALL_MESSAGES);
        enable_log_msg(REG_VVCT,  C_IDX_REG_MASTER, ID_BFM);
        enable_log_msg(REG_VVCT,  C_IDX_REG_MASTER, ID_FINISH_OR_STOP);

        log(ID_LOG_HDR, "Starting simulation of TB for drm_reg_bridge using VVCs", C_SCOPE);
        ------------------------------------------------------------

        log("Wait 10 clock period for reset to be turned off");
        wait for (10 * C_LINK_CLK_PERIOD); -- for reset to be turned off
        
        log(ID_LOG_HDR, "Configure VVCs", C_SCOPE);
        ------------------------------------------------------------
        shared_reg_vvc_config(C_IDX_REG_MASTER).bfm_config.clock_period := C_REG_CLK_PERIOD;
        shared_reg_vvc_config(C_IDX_REG_MASTER).bfm_config.max_wait_cycles := 100;
        shared_locallink_vvc_config(C_IDX_LL_MASTER).bfm_config.clock_period := C_LINK_CLK_PERIOD;
        shared_locallink_vvc_config(C_IDX_LL_SLAVE).bfm_config.clock_period  := C_LINK_CLK_PERIOD;
        shared_locallink_vvc_config(C_IDX_LL_SLAVE).bfm_config.check_packet_length := true;        

--        log(ID_LOG_HDR, "ECM write to DRM", C_SCOPE);
--        ------------------------------------------------------------
--        reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"0000", x"55555555", "ECM write to DRM: addr 0x0000");
--        reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"0000", x"AAAAAAAA", "ECM write to DRM: addr 0x0000");
--        reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"FFFF", x"55555555", "ECM write to DRM: addr 0xFFFF");
--        reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"FFFF", x"AAAAAAAA", "ECM write to DRM: addr 0xFFFF");
--        reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"0000", x"55555555", "ECM write to DRM: addr 0x0000");
--        reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"0000", x"AAAAAAAA", "ECM write to DRM: addr 0x0000");
--        reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"FFFF", x"55555555", "ECM write to DRM: addr 0xFFFF");
--        reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"FFFF", x"AAAAAAAA", "ECM write to DRM: addr 0xFFFF");
--        reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"0000", x"55555555", "ECM write to DRM: addr 0x0000");
--        reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"0000", x"AAAAAAAA", "ECM write to DRM: addr 0x0000");
--        reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"FFFF", x"55555555", "ECM write to DRM: addr 0xFFFF");
--        reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"FFFF", x"AAAAAAAA", "ECM write to DRM: addr 0xFFFF");
--        reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"0000", x"55555555", "ECM write to DRM: addr 0x0000");
--        reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"0000", x"AAAAAAAA", "ECM write to DRM: addr 0x0000");
--        reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"FFFF", x"55555555", "ECM write to DRM: addr 0xFFFF");
--        --reg_write(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"FFFF", x"AAAAAAAA", "ECM write to DRM: addr 0xFFFF");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"0000", x"55555555"), "DRM receive write request");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"0000", x"AAAAAAAA"), "DRM receive write request");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"FFFF", x"55555555"), "DRM receive write request");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"FFFF", x"AAAAAAAA"), "DRM receive write request");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"0000", x"55555555"), "DRM receive write request");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"0000", x"AAAAAAAA"), "DRM receive write request");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"FFFF", x"55555555"), "DRM receive write request");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"FFFF", x"AAAAAAAA"), "DRM receive write request");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"0000", x"55555555"), "DRM receive write request");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"0000", x"AAAAAAAA"), "DRM receive write request");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"FFFF", x"55555555"), "DRM receive write request");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"FFFF", x"AAAAAAAA"), "DRM receive write request");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"0000", x"55555555"), "DRM receive write request");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"0000", x"AAAAAAAA"), "DRM receive write request");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"FFFF", x"55555555"), "DRM receive write request");
--        --locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_write(C_ADDR_DRM_BASE + x"FFFF", x"AAAAAAAA"), "DRM receive write request");
--        --reg_check(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DWG_NUMBER, x"02050008", "Drawing number default");
--        await_completion(LOCALLINK_VVCT, C_IDX_LL_SLAVE, 100 * C_LINK_CLK_PERIOD);
--        
--        log(ID_LOG_HDR, "ECM read from DRM", C_SCOPE);
--        ------------------------------------------------------------
--        reg_check(REG_VVCT, C_IDX_REG_MASTER, C_ADDR_DRM_BASE + x"0000", x"55555555", "DRM read from ECM: addr 0x0000");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE,  cmd_read(C_ADDR_DRM_BASE + x"000"), "DRM receive read request");
--        await_completion(LOCALLINK_VVCT, C_IDX_LL_SLAVE, 10 * C_LINK_CLK_PERIOD);
--        locallink_transmit(LOCALLINK_VVCT, C_IDX_LL_MASTER, cmd_read_response(x"55555555"), "DRM transmit read response");
--        await_completion(REG_VVCT, C_IDX_REG_MASTER, 50 * C_REG_CLK_PERIOD);
        
        log(ID_LOG_HDR, "DRM write to ECM", C_SCOPE);
        ------------------------------------------------------------
        locallink_transmit(LOCALLINK_VVCT, C_IDX_LL_MASTER, cmd_write(C_ADDR_GPIO_DIR, x"FFFFFFFF"), "DRM transmit write request");
        await_completion(LOCALLINK_VVCT, C_IDX_LL_MASTER, 10 * C_LINK_CLK_PERIOD);
        
--        log(ID_LOG_HDR, "DRM read from ECM", C_SCOPE);
--        ------------------------------------------------------------
--        locallink_transmit(LOCALLINK_VVCT, C_IDX_LL_MASTER, cmd_read(C_ADDR_GPIO_DIR), "DRM transmit read request");
--        locallink_expect(LOCALLINK_VVCT, C_IDX_LL_SLAVE, cmd_read_response(x"000000FF"), "DRM receive read response");
--        await_completion(LOCALLINK_VVCT, C_IDX_LL_SLAVE, 50 * C_LINK_CLK_PERIOD);
        
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

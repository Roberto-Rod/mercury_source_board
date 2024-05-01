----------------------------------------------------------------------------------
--! @file tp_dds_restart.vhd
--! @brief Timing Protocol DDS restart module
--!
--! Instructs DDS interface when to prepare to restart a DDS line and when to
--! execute the restart.
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

--! @brief Timing Protocol DDS restart entity
--!
--! Instructs DDS interface when to prepare to restart a DDS line and when to
--! execute the restart.
entity tp_dds_restart is
    port (
        -- Register Bus
        clk                 : in std_logic;                         --! The register clock
        srst                : in std_logic;                         --! Register synchronous reset

        -- Blanking Inputs
        tp_ext_blank_n      : in std_logic;                         --! Masked and synchronised external blanking input
        tp_async_blank_n    : in std_logic;                         --! Asynchronous Timing Protocol blanking output

        -- DDS Line Restart
        dds_restart_prep    : out std_logic;                        --! Prepare DDS for line restart
        dds_restart_exec    : out std_logic                         --! Execute DDS line restart
    );
end tp_dds_restart;

architecture rtl of tp_dds_restart is
    constant C_EXT_BLANK_DURATION_THRESH : unsigned(12 downto 0) := to_unsigned(7999, 13);   --! 100 µs at 80 MHz

    signal ext_blank_timer : unsigned(C_EXT_BLANK_DURATION_THRESH'range);

    signal dds_restart_prep_a : std_logic;
    signal dds_restart_prep_b : std_logic;
    signal dds_restart_exec_a : std_logic;
    signal dds_restart_exec_b : std_logic;
begin
    -----------------------------------------------------------------------------
    --! Asynchronous Assignments
    -----------------------------------------------------------------------------

    -----------------------------------------------------------------------------
    --! @brief DDS restart prep/exec process
    --!
    --! Asserts restart prep if either source (external blanking or async TP)
    --! is asserting it. Asserts restart exec if either source is asserting it
    --! and neither source is asserting restart prep.
    --!
    --! @param[in]   clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_dds_prep: process(clk)
    begin
        if rising_edge(clk) then
            if srst = '1' then
                dds_restart_prep <= '0';
                dds_restart_exec <= '0';
            else
                dds_restart_prep <= dds_restart_prep_a or dds_restart_prep_b;
                dds_restart_exec <= (dds_restart_exec_a or dds_restart_exec_b) and
                                    (not dds_restart_prep_a) and (not dds_restart_prep_b);
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief External blanking duration detection process
    --!
    --! Detects external blanking so that DDS line restart can be commanded
    --! if external blanking exceeds duration threshold. This is to prevent
    --! the rapid Xchange blanking which is sourced externally from causing
    --! DDS line restart.
    --!
    --! @param[in]   clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_dds_restart_ext: process (clk)
    begin
        if rising_edge(clk) then
            if srst = '1' then
                ext_blank_timer  <= (others => '0');
                dds_restart_prep_a <= '0';
                dds_restart_exec_a <= '0';
            else
                -- Defaults
                dds_restart_exec_a <= '0';

                if tp_ext_blank_n = '0' then
                    if ext_blank_timer < C_EXT_BLANK_DURATION_THRESH then
                        ext_blank_timer <= ext_blank_timer + 1;
                    else
                        dds_restart_prep_a <= '1';
                    end if;
                else
                    ext_blank_timer  <= (others => '0');
                    dds_restart_prep_a <= '0';
                    dds_restart_exec_a <= dds_restart_prep_a;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief DDS line restart based on async TP
    --!
    --! Instructs DDS interface when to restart a line and outputs a prepare
    --! signal in advance.
    --!
    --! dds_restart_prep is high when asynchronous blanking is active (tp_async_blank_n = '0')
    --! or when external blanking has exceeded duration threshold. dds_restart_prep stays
    --! high until dds_restart_exec has been asserted high.
    --!
    --! dds_restart_exec is high for one-clock cycle when the line restart should be
    --! executed. This occurs when tp_async_blank_n is deasserted ('1') or, if
    --! external blanking had exceeded the duration threshold, when external blanking
    --! is de-asserted.
    --!
    --! @param[in]   clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_dds_restart_tp: process (clk)
    begin
        if rising_edge(clk) then
            if srst = '1' then
                dds_restart_prep_b <= '0';
                dds_restart_exec_b <= '0';
            else
                dds_restart_prep_b <= not tp_async_blank_n;
                dds_restart_exec_b <= dds_restart_prep_b and tp_async_blank_n;
            end if;
        end if;
    end process;

end rtl;

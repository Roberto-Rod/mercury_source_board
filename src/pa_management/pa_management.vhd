----------------------------------------------------------------------------------
--! @file pa_management.vhd
--! @brief PA management including dock comms
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
--! @version See Git logs
--! Updated
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


use work.mercury_pkg.all;
use work.reg_pkg.all;

------------------------------------------------------------------------------------
--! @brief Entity providing all of the PA control interfaces including dock comms
------------------------------------------------------------------------------------
entity pa_management is
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        reg_mosi            : in reg_mosi_type;                     --! Register master-out, slave-in signals
        reg_miso            : out reg_miso_type;                    --! Register master-in, slave-out signals

        -- VSWR Engine Bus
        vswr_mosi           : in vswr_mosi_type;                    --! VSWR engine master-out, slave-in signals
        vswr_miso           : out vswr_miso_type;                   --! VSWR engine master-in, slave-out signals

        -- Blanking Control
        int_blank_n         : in std_logic;                         --! Internal blanking input synchronised to reg_clk

        -- Internal PA Channel A control/status
        int_pa_mosi_a       : out pa_management_mosi_type;
        int_pa_miso_a       : in pa_management_miso_type;
        int_pa_bidir_a      : inout pa_management_bidir_type;

        -- Dock Channel A Comms
        dock_comms_ro_a     : in std_logic;
        dock_comms_re_n_a   : out std_logic;
        dock_comms_de_a     : out std_logic;
        dock_comms_di_a     : out std_logic;

        -- Dock Channel A Blank Control
        dock_blank_re_n_a   : out std_logic;
        dock_blank_de_a     : out std_logic;
        dock_blank_di_a     : out std_logic
    );
end pa_management;

architecture rtl of pa_management is
    -- Register storage
    type pa_regs_t is array (integer range 0 to 0) of std_logic_vector(4 downto 0);
    signal pa_regs : pa_regs_t := (others => (others => '0'));

    -- Register buses
    signal reg_srst_dq              : std_logic;
    signal reg_mosi_dq              : reg_mosi_type;
    signal reg_miso_i2c             : reg_miso_type;
    signal reg_miso_spi             : reg_miso_type;
    signal reg_miso_pa_mgmt         : reg_miso_type;
    signal reg_miso_dock            : reg_miso_type;
    signal reg_miso_dummy           : reg_miso_type;

    -- VSWR buses
    signal vswr_miso_int            : vswr_miso_type;
    signal vswr_miso_dock           : vswr_miso_type;

    -- Synchronised PA control alert
    signal pa_ctrl_alert_s          : std_logic;
begin
    -- Dock blanking uses half-duplex transceivers for "future use" but
    -- they are only used as unidirectional transmitters so fix mode.
    dock_blank_re_n_a          <= '1';
    dock_blank_de_a            <= '1';

    -- Always feed the internal blanking signal to the dock
    dock_blank_di_a           <= int_blank_n;

    -- PA Control Registers
    ----------------------------------------------------------------------------
    -- Bit | Name               | Description
    -------|--------------------|-----------------------------------------------
    -- 2   | pa_blank           | Force PA into blank (mute) mode (high)
    -- 1   | pa_shdn            | Shutdown PA (high)
    -- 0   | monitor_en         | Enable post-PA power monitor
    -------|--------------------|-----------------------------------------------
    int_pa_mosi_a.ctrl_mute_n <= int_blank_n and not pa_regs(0)(2);
    int_pa_mosi_a.ctrl_shdn   <= pa_regs(0)(1);
    int_pa_mosi_a.monitor_en  <= pa_regs(0)(0);

    -----------------------------------------------------------------------------
    --! @brief Register read/write process, synchronous to reg_clk.
    --!
    --! Handles PA management registers
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    reg_rd_wr_proc: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst_dq = '1' then
                reg_miso_pa_mgmt.data <= (others => '0');
                reg_miso_pa_mgmt.ack  <= '0';
                pa_regs <= (others => "00010");
            else
                -- Defaults
                reg_miso_pa_mgmt.data <= (others => '0');
                reg_miso_pa_mgmt.ack  <= '0';

                if reg_mosi_dq.valid = '1' then
                    if reg_mosi_dq.addr = REG_ADDR_INT_PA_CONTROL then
                        if reg_mosi_dq.rd_wr_n = '1' then
                            -- Read register
                            reg_miso_pa_mgmt.data <= pa_ctrl_alert_s & "000" &
                                                     x"00000" &
                                                     "000" & pa_regs(0);
                            reg_miso_pa_mgmt.ack  <= '1';
                        else
                            -- Write Register
                            pa_regs(0) <= reg_mosi_dq.data(4 downto 0);
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    i2c_master_pa: entity work.i2c_master_top
    generic map(
        REGISTER_BASE_ADDRESS      => REG_ADDR_BASE_I2C_INT_PA,
        CONTROL_REGISTER_ADDRESS   => REG_ADDR_CONTROL_I2C_INT_PA,
        I2C_SLAVE_ADDR             => PA_CTRL_I2C_SLAVE_ADDR
    )
    port map(
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst_dq,
        reg_mosi            => reg_mosi_dq,
        reg_miso            => reg_miso_i2c,

        -- I2C signals
        scl                 => int_pa_bidir_a.ctrl_scl,
        sda                 => int_pa_bidir_a.ctrl_sda
    );

    i_pwr_mon_top: entity work.pwr_mon_top
    generic map(
        REGISTER_ADDRESS  => REG_ADDR_INT_PA_PWR_MON,
        MAF_COEFF_ADDRESS => REG_ADDR_INT_PA_MAF_COEFF,
        MAF_DELAY_ADDRESS => REG_ADDR_INT_PA_MAF_DELAY,
        VSWR_ADDRESS      => VSWR_ADDR_INT
    )
    port map(
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst_dq,
        reg_mosi            => reg_mosi_dq,
        reg_miso            => reg_miso_spi,
        
        -- Blanking Control
        int_blank_n         => int_blank_n,

        -- VSWR Engine Signals
        vswr_mosi           => vswr_mosi,
        vswr_miso           => vswr_miso_int,

        -- ADC signals
        adc_cs_n            => int_pa_mosi_a.monitor_cs_n,
        adc_sclk            => int_pa_mosi_a.monitor_sck,
        adc_mosi            => int_pa_mosi_a.monitor_mosi,
        adc_miso            => int_pa_miso_a.monitor_miso
    );

    i_dock_comms: entity work.dock_comms
    generic map ( VSWR_ADDRESS => VSWR_ADDR_DOCK )
    port map(
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst_dq,
        reg_mosi            => reg_mosi_dq,
        reg_miso            => reg_miso_dock,

        -- VSWR Engine Signals
        vswr_mosi           => vswr_mosi,
        vswr_miso           => vswr_miso_dock,

        -- Dock RS485 Transceiver Pins
        dock_comms_ro       => dock_comms_ro_a,
        dock_comms_re_n     => dock_comms_re_n_a,
        dock_comms_de       => dock_comms_de_a,
        dock_comms_di       => dock_comms_di_a
    );

    i_vswr_miso_mux: entity work.vswr_miso_mux
    port map(
        -- Clock
        clk                 => reg_clk,

        -- Input data/valid
        vswr_miso_i_1       => vswr_miso_int,
        vswr_miso_i_2       => vswr_miso_dock,

        -- Output data/valid
        vswr_miso_o         => vswr_miso
    );

    i_reg_mosi_dq: entity work.reg_mosi_dq
    port map(
        reg_clk             => reg_clk,

        reg_mosi_i          => reg_mosi,
        reg_srst_i          => reg_srst,

        reg_mosi_o          => reg_mosi_dq,
        reg_srst_o          => reg_srst_dq
    );

    reg_miso_dummy.data <= (others => '0');
    reg_miso_dummy.ack  <= '0';

    i_reg_miso_mux: entity work.reg_miso_mux6
    port map (
        -- Clock
        reg_clk             => reg_clk,

        -- Input data/valid
        reg_miso_i_1        => reg_miso_i2c,
        reg_miso_i_2        => reg_miso_spi,
        reg_miso_i_3        => reg_miso_pa_mgmt,
        reg_miso_i_4        => reg_miso_dock,
        reg_miso_i_5        => reg_miso_dummy,
        reg_miso_i_6        => reg_miso_dummy,

        -- Output data/valid
        reg_miso_o          => reg_miso
    );

    i_pa_ctrl_alert_sync: entity work.slv_synchroniser
    generic map ( bits => 1, sync_reset => true )
    port map ( rst => reg_srst, clk => reg_clk, din(0) => int_pa_miso_a.ctrl_alert, dout(0) => pa_ctrl_alert_s );

end rtl;



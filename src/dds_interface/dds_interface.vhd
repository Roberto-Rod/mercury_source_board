----------------------------------------------------------------------------------
--! @file dds_interface.vhd
--! @brief DDS Interface Module
--!
--! Provides register & jamming engine interface to DDS.
--! Also provides VSWR & blanking synchronisation signals.
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
--! @version See Git logs
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

use work.mercury_pkg.all;
use work.reg_pkg.all;

library unisim;
use unisim.vcomponents.all;

--! @brief Entity providing register and jamming engine interface to the DDS
entity dds_interface is
    generic(
        SYNC_CLKS_PER_SEC   : integer := 135000000
    );
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        reg_mosi            : in reg_mosi_type;                     --! Register master-out, slave-in signals
        reg_miso            : out reg_miso_type;                    --! Register master-in, slave-out signals

        -- Jamming engine interface signals        
        jam_rd_en           : out std_logic;                        --! Read jamming line data from FWFT FIFO
        jam_data            : in std_logic_vector(31 downto 0);     --! Jamming line read data        
        jam_terminate_line  : in std_logic;                         --! Jamming line data ready flag
        jam_fifo_empty      : in std_logic;                         --! Jamming engine FIFO empty
        jam_en_n            : in std_logic;                         --! Jamming engine enable (disable manual control)
        jam_rf_ctrl         : out std_logic_vector(31 downto 0);    --! Jamming engine RF control word
        jam_rf_ctrl_valid   : out std_logic;                        --! Jamming engine RF control word valid

        -- VSWR engine signals
        vswr_line_start     : out std_logic;                        --! Asserted high for one clock cycle when VSWR test line starts

        -- Blanking signals
        jam_blank_out_n     : out std_logic;                        --! Jamming blank output
        blank_in_n          : in std_logic;                         --! Internal blanking input signal

        -- Internal 1PPS signal
        int_pps_i           : in std_logic;                         --! FPGA internal 1PPS signal

        -- Timing Protocol control
        tp_sync_en          : in std_logic;                         --! Synchronous Timing Protocol enable
        dds_restart_prep    : in std_logic;                         --! Prepare DDS for line restart (async TP)
        dds_restart_exec    : in std_logic;                         --! Execute DDS line restart (async TP)

        -- Control signals
        pwr_en_1v8          : out std_logic;                        --! DDS core power supply enable

        -- AD9914 signals
        dds_ext_pwr_dwn     : out std_logic;                        --! DDS power down
        dds_reset           : out std_logic;                        --! DDS asynchronous reset signal, active high
        dds_d               : inout std_logic_vector(31 downto 0);  --! DDS data/address/serial pins
        dds_osk             : out std_logic;                        --! DDS On-Off Shift Keying (OSK) output
        dds_io_update       : out std_logic;                        --! IO Update line
        dds_dr_over         : in std_logic;                         --! "Digital ramp over" signal
        dds_dr_hold         : out std_logic;                        --! "Digital ramp hold" signal
        dds_dr_ctl          : out std_logic;                        --! "Digital ramp control" signal
        dds_sync_clk        : in std_logic;                         --! DDS sync clock signal
        dds_ps              : out std_logic_vector(2 downto 0);     --! DDS profile select
        dds_f               : out std_logic_vector(3 downto 0);     --! DDS function - selects SPI/parallel interface

        -- Daughter Board ID
        dgtr_id             : in std_logic_vector(3 downto 0)       --! Daughter board ID
     );
end dds_interface;

architecture rtl of dds_interface is
    -- Local constants
    constant DDS_SERIAL_MODE        : std_logic_vector(3 downto 0) := "0001";
    constant DDS_PARALLEL_MODE      : std_logic_vector(3 downto 0) := "0000";
    -- TODO: make these parameters so that clock could be adjusted
    constant C_MIN_BLANK_PERIOD     : unsigned(31 downto 0) := to_unsigned(67, 32);    -- Duration counter value for 0.5 µs at 135 MHz
    constant C_POSN_ADJUST_MAX      : unsigned(26 downto 0) := to_unsigned(1350, 27);  -- 10 µs at 135 MHz
    constant C_PPS_POSN_CNT_MAX     : signed(27 downto 0) := to_signed((SYNC_CLKS_PER_SEC/2)-1, 28);
    constant C_PPS_POSN_CNT_MIN     : signed(27 downto 0) := to_signed(-(SYNC_CLKS_PER_SEC/2), 28);

    -- Start of line timer
    constant C_SOL_BLANK_TIME       : unsigned(5 downto 0) := to_unsigned(40, 6);      -- 296.3 ns at 135 MHz

    -- DDS Address Constants
    -- Address byte 1 out of bytes 0 to 3 in 16-bit parallel mode to write bytes 1 & 0,
    -- address is then offset by 2 to write bytes 3 & 2
    constant DDS_PRL_ADD_DRLL       : std_logic_vector(7 downto 0) := x"11";         --! DDS parallel address 0x11 (Digital Ramp Lower Limit, Byte 1)
    constant DDS_PRL_ADD_RDRSS      : std_logic_vector(7 downto 0) := x"19";         --! DDS parallel address 0x19 (Rising Digital Ramp Step Size, Byte 1)
    constant DDS_PRL_ADD_P0PAR      : std_logic_vector(7 downto 0) := x"31";         --! DDS parallel address 0x31 (Profile 0 Phase/Amplitude Register, Byte 1)

    -- Enumerations
    constant C_BLANK_CONTINUE       : std_logic_vector(1 downto 0) := "00";          --! Action on async blanking: continue in background
    constant C_BLANK_RESTART        : std_logic_vector(1 downto 0) := "01";          --! Action on async blanking: restart when blank is removed

    -- DDS tri-state signals
    signal dds_d_in                 : std_logic_vector(31 downto 16);               --! DDS data/address/serial pins - input
    signal dds_d_out                : std_logic_vector(31 downto 0);                --! DDS data/address/serial pins - output
    signal dds_d_t                  : std_logic_vector(31 downto 16);               --! DDS data/address/serial pins - tri-state control

    -- DDS parallel read/write state machine
    type fsm_dds_parallel_t is (IDLE, WR_1_1,  WR_1_2,  WR_1_3,  WR_2_1,  WR_2_2,  WR_2_3,  WR_2_4,
                                      RD_1_1,  RD_1_2,  RD_1_3,  RD_1_4,  RD_1_5,  RD_1_6,  RD_1_7,  RD_1_8,
                                      RD_1_9,  RD_1_10, RD_1_11, RD_1_12, RD_1_13, RD_1_14, RD_1_15, RD_1_16,
                                      RD_1_17, RD_1_18, RD_1_19, RD_1_20, RD_1_21, RD_1_22, RD_1_23,
                                      RD_2_1,  RD_2_2,  RD_2_3,  RD_2_4,  RD_2_5,  RD_2_6,  RD_2_7,  RD_2_8,
                                      RD_2_9,  RD_2_10, RD_2_11, RD_2_12, RD_2_13, RD_2_14, RD_2_15, RD_2_16,
                                      RD_2_17, RD_2_18, RD_2_19, RD_2_20, RD_2_21, RD_2_22, RD_2_23
                                );
    signal fsm_dds_parallel : fsm_dds_parallel_t := IDLE;

    -- Jamming line reading state machine
    type fsm_jam_rd_t is (JAM_IDLE, JAM_RESTART_CTRL, JAM_RESTART_FTW, JAM_RESTART_DFTW, JAM_RESTART_ASF_POW, JAM_RESTART_DUR,
                          JAM_RD_CTRL, JAM_RD_FTW, JAM_RD_DFTW, JAM_RD_ASF_POW, JAM_RD_DUR, JAM_TERMINATE);
    signal fsm_jam_rd      : fsm_jam_rd_t := JAM_IDLE;
    signal fsm_jam_rd_next : fsm_jam_rd_t := JAM_IDLE;

    -- DDS aliases
    alias dds_addr_out             : std_logic_vector(7 downto 0)  is dds_d_out(15 downto 8);
    alias dds_data_out             : std_logic_vector(15 downto 0) is dds_d_out(31 downto 16);
    alias dds_data_in              : std_logic_vector(15 downto 0) is dds_d_in(31 downto 16);
    alias dds_wr_n                 : std_logic is dds_d_out(2);
    alias dds_rd_n                 : std_logic is dds_d_out(1);
    alias dds_16bit                : std_logic is dds_d_out(0);

    -- Internal (FPGA) Registers
    signal dds_ctrl_register       : std_logic_vector(31 downto 0) := DDS_CTRL_RESET_VAL;

    --! Asynchronous data reset (used for synchronisers)
    signal drst                    : std_logic := '0';

    -- Register-to-DDS internal signals
    signal reg_dds_dout            : std_logic_vector(31 downto 0);
    signal reg_dds_addr            : std_logic_vector(5 downto 0);
    signal reg_dds_dout_valid      : std_logic;
    signal reg_dds_rd_wr_n         : std_logic;

    -- Signals resynchronised into dds_sync_clk domain
    signal reg_dds_dout_s          : std_logic_vector(31 downto 0);
    signal reg_dds_addr_s          : std_logic_vector(5 downto 0);
    signal reg_dds_rd_wr_n_s       : std_logic;
    signal reg_dds_dout_valid_s    : std_logic;

    -- DDS-to-register internal signals
    signal dds_din                 : std_logic_vector(31 downto 0);
    signal dds_din_valid           : std_logic;

    -- Signals resynchronised into reg_clk domain
    signal dds_din_s               : std_logic_vector(31 downto 0);
    signal dds_din_valid_s         : std_logic;
    signal dds_din_valid_s_r       : std_logic;
    signal dds_din_valid_s_rr      : std_logic;
    signal dds_din_reg             : std_logic_vector(31 downto 0);
    signal dds_din_valid_reg       : std_logic;

    -- Jamming engine DDS data
    signal jam_dds_dout            : std_logic_vector(31 downto 0);
    signal jam_dds_addr            : std_logic_vector(7 downto 0);
    signal jam_dds_dout_valid      : std_logic := '0';

    -- Parallel mode FSM data/addr signals
    signal dds_prl_data            : std_logic_vector(31 downto 0);                    --! Parallel 32-bit data
    signal dds_prl_addr            : std_logic_vector(7 downto 0);                     --! Parallel 8-bit address

    -- Register read signals
    signal reg_dout                : std_logic_vector(31 downto 0);
    signal reg_dout_valid          : std_logic;

    -- IO_UPDATE control
    signal io_update_shift         : std_logic_vector(1 downto 0) := "00";
    signal io_update_req           : std_logic;
    signal io_update_req_s         : std_logic;

    -- DRCTL control
    signal drctl_shift             : std_logic_vector(1 downto 0);
    signal drctl_req               : std_logic;
    signal drctl_req_s             : std_logic;

    -- Line duration counter
    signal io_update_count         : unsigned(31 downto 0) := (others => '0');
    signal io_update_next_dur      : unsigned(31 downto 0);
    signal io_update_next_dur_inc  : unsigned(31 downto 0);
    signal io_update_next_dur_dec  : unsigned(31 downto 0);
    signal io_update_next_dur_adj  : unsigned(31 downto 0);
    signal io_update_next_dur_o    : unsigned(31 downto 0);
    signal io_update_next_comp     : unsigned(31 downto 0);
    signal io_update_use_min       : std_logic;
    signal io_update_hold          : std_logic;

    -- Update flag
    signal update_flag             : std_logic := '0';
    signal update_flag_s           : std_logic := '0';

    -- Sweep ready signal
    signal dds_sweep_rdy           : std_logic := '1';
    signal first_line              : std_logic := '1';

    -- Jam start signal
    signal jam_start               : std_logic := '0';
    signal wait_count              : unsigned(2 downto 0);

    -- DDS line restart signals
    type t_double_reg is array (integer range 0 to 1) of std_logic_vector(31 downto 0);
    signal rf_ctrl_store           : t_double_reg;
    signal dds_ftw_store           : t_double_reg;
    signal dds_dftw_store          : t_double_reg;
    signal dds_asf_pow_store       : t_double_reg;
    signal dds_duration_store      : t_double_reg;
    signal dds_ftw_latest          : std_logic_vector(31 downto 0);
    signal dds_ftw_prev            : std_logic_vector(31 downto 0);
    signal restart_index           : unsigned(0 downto 0);
    signal reload_next_line        : std_logic;
    signal blank_action            : std_logic_vector(1 downto 0);
    signal dds_mute_n              : std_logic;
    signal restart_prepared        : std_logic;
    
    -- DDS line restart synchronised into dds_sync_clk domain
    signal dds_restart_prep_s      : std_logic;
    signal dds_restart_exec_s      : std_logic;
    signal dds_restart_exec_hold   : std_logic;

    -- Duration/valid signal
    signal dds_duration            : std_logic_vector(31 downto 0);
    signal dds_duration_valid      : std_logic := '0';
    signal dds_duration_valid_r    : std_logic;
    signal dds_duration_valid_rr   : std_logic;
    signal dds_duration_valid_rrr  : std_logic;

    -- RF control cross clock-domain
    signal rf_ctrl                 : std_logic_vector(31 downto 0);
    signal rf_ctrl_s               : std_logic_vector(31 downto 0);
    signal rf_ctrl_s_r             : std_logic_vector(31 downto 0);
    signal rf_ctrl_prev            : std_logic_vector(31 downto 0);

    -- Jamming enable cross clock-domain
    signal jam_en_n_s              : std_logic := '0';                                 --! dds_sync_clk domain

    -- Blanking cross clock-domain
    signal blank_in_n_s            : std_logic;                                        --! dds_sync_clk domain

    -- Start of line blanking/timer
    signal sol_blank_n             : std_logic;                                        --! Start of line blanking
    signal sol_timer               : unsigned(5 downto 0);                             --! Start of line timer

    -- 1PPS cross clock-domain
    signal int_pps_s               : std_logic;                                        --! dds_sync_clk domain
    signal int_pps_s_r             : std_logic;                                        --! dds_sync_clk domain

    -- Synchronous TP mode, error detection, count in sync clock domain
    signal pps_posn_cnt            : signed(27 downto 0);                              --! 1PPS position counter
    signal pps_posn_err            : signed(27 downto 0);                              --! 1PPS position error
    signal pps_posn_err_lo         : signed(27 downto 0);                              --! 1PPS position error, low side of 1PPS
    signal pps_posn_err_lo_abs     : signed(27 downto 0);                              --! 1PPS position error, low side of 1PPS, absolute
    signal pps_posn_err_hi         : signed(27 downto 0);                              --! 1PPS position error, high side of 1PPS
    signal pps_posn_err_hi_abs     : signed(27 downto 0);                              --! 1PPS position error, high side of 1PPS, absolute
    signal posn_adjust             : unsigned(26 downto 0);                            --! Adjustment value to make
    signal posn_adjust_acc         : unsigned(26 downto 0);                            --! Adjustment accumulator
    signal posn_adjust_ltd         : unsigned(26 downto 0);                            --! Adjustment limited to max allowed adjustment
    signal posn_adjust_acc_sub     : unsigned(26 downto 0);                            --! Accumulator subtrahend
    signal posn_adjust_acc_o       : unsigned(26 downto 0);                            --! Re-calculated accumulator
    signal posn_adjust_valid       : std_logic;
    signal posn_inc_dec_n          : std_logic;                                        --! Adjustment direction
    signal pps_posn_err_valid      : std_logic;
    signal pps_err_sel             : std_logic;
    signal capture_position_flag   : std_logic;
    signal first_capture           : std_logic;
    signal sequence_start          : std_logic;

    -- Sync clk detection & counter
    signal sync_clk_count          : unsigned(27 downto 0) := (others => '0');         --! dds_sync_clk domain
    signal sync_clk_hold           : std_logic_vector(27 downto 0);                    --! dds_sync_clk domain
    signal sync_clk_hold_s         : std_logic_vector(27 downto 0);                    --! reg_clk domain

    signal reg_clk_count           : unsigned(26 downto 0) := (others => '0');         --! reg_clk domain

    signal sync_clk_tick           : std_logic;                                        --! dds_sync_clk domain
    signal sync_clk_tick_s         : std_logic;                                        --! reg_clk domain

    signal sync_clk_tick_sr        : unsigned(2 downto 0);                             --! reg_clk domain
    signal sync_clk_detect         : std_logic;                                        --! reg_clk domain

    signal one_sec_sync            : std_logic;                                        --! reg_clk domain
    signal one_sec_sync_s          : std_logic;                                        --! dds_sync_clk domain
    signal one_sec_sync_s_r        : std_logic;                                        --! dds_sync_clk domain
begin
    -- Always enable 1V8 as this is needed to make DDS actually power down when EXT_PWR_DWN is asserted
    pwr_en_1v8 <= '1';

    -- Function pins
    dds_f <= DDS_PARALLEL_MODE;

    -- IO Update pulse
    dds_io_update <= update_flag;

    -- Hold the sweep when IO Update is being held to stop the DDS from sweeping into oblivion
    dds_dr_hold <= io_update_hold;

    -----------------------------------------------------------------------------
    --! @brief Register read/write process, synchronous to reg_clk.
    --!
    --! Handles control register for this module
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_reg_rd_wr: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            -- Defaults
            reg_dout <= (others => '0');
            reg_dout_valid <= '0';
            io_update_req <= '0';
            drctl_req <= '0';

            if reg_srst = '1' then
                -- Synchronous Reset
                dds_ctrl_register <= DDS_CTRL_RESET_VAL;
            elsif reg_mosi.valid = '1' then
                if unsigned(reg_mosi.addr) = unsigned(REG_ADDR_DDS_CTRL) then
                    -- Read Control Register
                    if reg_mosi.rd_wr_n = '1' then
                        reg_dout_valid <= '1';
                        reg_dout <= dds_ctrl_register;
                    -- Write Control Register
                    else
                        dds_ctrl_register <= reg_mosi.data;
                    end if;

                elsif unsigned(reg_mosi.addr) = unsigned(REG_ADDR_DDS_IO_UPDATE) then
                    -- Initiate an IO_UPDATE (ignore the write data)
                    if reg_mosi.rd_wr_n = '0' then
                        io_update_req <= '1';
                    end if;

                elsif unsigned(reg_mosi.addr) = unsigned(REG_ADDR_DDS_DRCTL) then
                    -- Write only: Initiate a DRCTL update (ignore the write data)
                    if reg_mosi.rd_wr_n = '0' then
                        drctl_req <= '1';
                    end if;

                elsif unsigned(reg_mosi.addr) = unsigned(REG_ADDR_DDS_CLK_COUNT) then
                    -- Read only: Return the DDS clock count
                    if reg_mosi.rd_wr_n = '1' then
                        reg_dout_valid <= '1';

                        -- Set output data if sync clk is detected, otherwise data defaults to all zeros
                        if sync_clk_detect = '1' then
                            reg_dout <= "0000" & sync_clk_hold_s;
                        end if;
                    end if;

                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief DDS read/write process, synchronous to reg_clk.
    --!
    --! Handles DDS read/write requests
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_dds_dout: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            -- Defaults
            reg_dds_dout_valid <= '0';

            -- Transfer register data/address to internal DDS signals
            if jam_en_n = '1' then
                -- Manual control mode, assign register data to DDS signals,
                -- these only get applied when dds_dout_valid is asserted
                reg_dds_addr    <= reg_mosi.addr(5 downto 0);
                reg_dds_dout    <= reg_mosi.data;
                reg_dds_rd_wr_n <= reg_mosi.rd_wr_n;

                if reg_mosi.valid = '1' and unsigned(reg_mosi.addr(23 downto 6)) = unsigned(REG_ADDR_DDS_REGS_BASE(23 downto 6)) then
                    -- DDS registers mapped to FPGA register addresses. 6 LSBs are DDS register address.
                    -- Initiate DDS read/write
                    reg_dds_dout_valid <= '1';
                end if;
            end if;
        end if;
    end process;
    
    p_jam_fsm_next_state: process(fsm_jam_rd_next, jam_terminate_line, jam_en_n_s)
    begin
        if jam_terminate_line = '1' then
            fsm_jam_rd <= JAM_TERMINATE;
        else
            fsm_jam_rd <= fsm_jam_rd_next;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Jamming engine read process, synchronous to dds_sync_clk.
    --!
    --! @param[in]   dds_sync_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_jam_rd: process(dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            if jam_en_n_s = '1' then
                first_line            <= '1';
                restart_prepared      <= '0';
                jam_dds_dout_valid    <= '0';
                jam_rd_en             <= '0';
                wait_count            <= (others => '1');
                restart_index         <= (others => '0');
                reload_next_line      <= '0';
                io_update_hold        <= '0';
                dds_restart_exec_hold <= '0';
                fsm_jam_rd_next       <= JAM_IDLE;
            else
                -- Default
                jam_dds_dout_valid    <= '0';
                dds_duration_valid    <= '0';

                if dds_restart_exec_s = '1' and restart_prepared = '1' then
                    dds_restart_exec_hold <= '1';
                    restart_prepared      <= '0';
                end if;

                case fsm_jam_rd is                        
                    when JAM_IDLE =>
                        jam_rd_en <= '0';

                        if wait_count > 0 then
                            wait_count <= wait_count - 1;
                        else
                            -- Are we ready to reload DDS?
                            if dds_sweep_rdy = '1' then
                                -- Do we need to reload the next line?
                                if reload_next_line = '1' then
                                    fsm_jam_rd_next  <= JAM_RESTART_CTRL;
                                    restart_index    <= to_unsigned(1, restart_index'length);
                                    reload_next_line <= '0';
                                    first_line       <= '0';
                                -- Not reloading a line, is data ready?
                                elsif jam_fifo_empty = '0' then
                                    dds_restart_exec_hold <= '0';
                                    fsm_jam_rd_next       <= JAM_RD_CTRL;
                                    first_line            <= '0';
                                end if;
                            -- Not ready to reload DDS, are we preparing for a line restart?
                            -- Only allowed if TP is not in sync mode
                            elsif tp_sync_en = '0' and dds_restart_prep_s = '1' and first_line = '0' and
                                  unsigned(blank_action) = unsigned(C_BLANK_RESTART) then
                                fsm_jam_rd_next  <= JAM_RESTART_CTRL;
                                restart_prepared <= '1';
                                restart_index    <= to_unsigned(0, restart_index'length);
                                io_update_hold   <= '1';
                            end if;
                        end if;

                    when JAM_RESTART_CTRL =>
                        -- Re-transfer current RF control register
                        rf_ctrl          <= rf_ctrl_store(to_integer(restart_index));                        
                        fsm_jam_rd_next  <= JAM_RESTART_FTW;
                        wait_count       <= "001";

                    when JAM_RESTART_FTW =>
                        if wait_count > 0 then
                            wait_count <= wait_count - 1;
                        else
                            -- Re-transfer current FTW to DDS
                            jam_dds_addr       <= DDS_PRL_ADD_DRLL;
                            jam_dds_dout       <= dds_ftw_store(to_integer(restart_index));
                            jam_dds_dout_valid <= '1';
                            dds_ftw_latest     <= dds_ftw_store(to_integer(restart_index));
                            fsm_jam_rd_next    <= JAM_RESTART_DFTW;
                            wait_count         <= "111";
                        end if;

                    when JAM_RESTART_DFTW =>
                        if wait_count > 0 then
                            wait_count <= wait_count - 1;
                        else
                            -- Re-transfer current DFTW to DDS
                            jam_dds_addr       <= DDS_PRL_ADD_RDRSS;
                            jam_dds_dout       <= dds_dftw_store(to_integer(restart_index));
                            jam_dds_dout_valid <= '1';
                            fsm_jam_rd_next    <= JAM_RESTART_ASF_POW;
                            wait_count         <= "111";
                        end if;

                    when JAM_RESTART_ASF_POW =>
                        if wait_count > 0 then
                            wait_count <= wait_count - 1;
                        else
                            -- Re-transfer current ASF/POW to DDS
                            jam_dds_addr       <= DDS_PRL_ADD_P0PAR;
                            jam_dds_dout       <= dds_asf_pow_store(to_integer(restart_index));
                            jam_dds_dout_valid <= '1';
                            fsm_jam_rd_next    <= JAM_RESTART_DUR;
                            wait_count         <= "001";
                        end if;

                    when JAM_RESTART_DUR =>
                        if wait_count > 0 then
                            wait_count <= wait_count - 1;
                        else
                            -- Re-transfer duration
                            dds_duration       <= dds_duration_store(to_integer(restart_index));
                            dds_duration_valid <= '1';

                            if restart_index = 0 then
                                reload_next_line <= '1';

                                -- Wait for restart to be executed
                                if dds_restart_exec_hold = '1' then
                                    io_update_hold        <= '0';
                                    dds_restart_exec_hold <= '0';
                                    fsm_jam_rd_next       <= JAM_IDLE;
                                    wait_count            <= "001";
                                end if;
                            else                                
                                fsm_jam_rd_next  <= JAM_IDLE;
                                wait_count       <= "001";
                            end if;
                        end if;

                    when JAM_RD_CTRL =>
                        -- Transfer current jamming word to RF control register and read next jamming word
                        rf_ctrl_store(1) <= jam_data;
                        rf_ctrl          <= jam_data;
                        jam_rd_en        <= '1';
                        fsm_jam_rd_next  <= JAM_RD_FTW;
                        wait_count       <= "001";

                    when JAM_RD_FTW =>
                        if wait_count > 0 then
                            wait_count <= wait_count - 1;
                            jam_rd_en  <= '0';
                        else
                            -- Transfer current word to DDS and read next jamming word
                            dds_ftw_store(1)   <= jam_data;
                            dds_ftw_latest     <= jam_data;
                            jam_dds_addr       <= DDS_PRL_ADD_DRLL;
                            jam_dds_dout       <= jam_data;
                            jam_dds_dout_valid <= '1';
                            jam_rd_en          <= '1';
                            fsm_jam_rd_next    <= JAM_RD_DFTW;
                            wait_count         <= "111";
                        end if;

                    when JAM_RD_DFTW =>
                        if wait_count > 0 then
                            wait_count <= wait_count - 1;
                            jam_rd_en <= '0';
                        else
                            -- Transfer current word to DDS and read next jamming word
                            dds_dftw_store(1)  <= jam_data;
                            jam_dds_addr       <= DDS_PRL_ADD_RDRSS;
                            jam_dds_dout       <= jam_data;
                            jam_dds_dout_valid <= '1';
                            jam_rd_en          <= '1';
                            fsm_jam_rd_next    <= JAM_RD_ASF_POW;
                            wait_count         <= "111";
                        end if;

                    when JAM_RD_ASF_POW =>
                        if wait_count > 0 then
                            wait_count <= wait_count - 1;
                            jam_rd_en <= '0';
                        else
                            -- Transfer current word to DDS and read next jamming word
                            dds_asf_pow_store(1) <= jam_data;
                            jam_dds_addr         <= DDS_PRL_ADD_P0PAR;
                            jam_dds_dout         <= jam_data;
                            jam_dds_dout_valid   <= '1';
                            jam_rd_en            <= '1';
                            fsm_jam_rd_next      <= JAM_RD_DUR;
                            wait_count           <= "001";
                        end if;

                    when JAM_RD_DUR =>
                        if wait_count > 0 then
                            wait_count <= wait_count - 1;
                            jam_rd_en <= '0';
                        else
                            -- Transfer duration and read next jamming word
                            dds_duration_store(1) <= jam_data;
                            dds_duration          <= jam_data;
                            dds_duration_valid    <= '1';
                            jam_rd_en             <= '1';
                            fsm_jam_rd_next       <= JAM_IDLE;
                            wait_count            <= "001";
                        end if;
                        
                    when JAM_TERMINATE =>
                        first_line            <= '1';
                        restart_prepared      <= '0';
                        jam_dds_dout_valid    <= '0';
                        jam_rd_en             <= '0';
                        wait_count            <= to_unsigned(2, wait_count'length);
                        restart_index         <= (others => '0');
                        reload_next_line      <= '0';
                        io_update_hold        <= '0';
                        dds_restart_exec_hold <= '0';
                        fsm_jam_rd_next       <= JAM_IDLE;
                end case;

            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Process which drives register/DDS data back to master
    --!
    --! OR's data from DDS and internal (FPGA) control register
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_reg_dout: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            dds_din_valid_s_r <= dds_din_valid_s;
            dds_din_valid_s_rr <= dds_din_valid_s_r;

            if ( dds_din_valid_s_r = '1' and dds_din_valid_s_rr = '0' ) then
                dds_din_reg <= dds_din_s;
                dds_din_valid_reg <= '1';
            else
                dds_din_reg <= (others => '0');
                dds_din_valid_reg <= '0';
            end if;

            reg_miso.data <= reg_dout or dds_din_reg;
            reg_miso.ack  <= reg_dout_valid or dds_din_valid_reg;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Finite State Machine which reads/writes DDS data in parallel mode
    --!
    --! @param[in]   dds_sync_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_fsm: process(reg_srst, dds_sync_clk)
    begin
        if reg_srst = '1' then
            fsm_dds_parallel <= IDLE;
            dds_din_valid <= '0';
            -- Tri-state control: 0=output
            dds_d_t   <= (others => '0');   -- Tri-state control: 0=output
            dds_d_out <= x"00000007";       -- Fix in 16-bit mode & set rd_n, wr_n high
        elsif rising_edge(dds_sync_clk) then
            case fsm_dds_parallel is
                ----------------
                -- IDLE STATE --
                ----------------
                when IDLE =>
                    -- If either the jamming engine or the register interface are performing a register
                    -- access then latch the data/address
                    if jam_dds_dout_valid = '1' then
                        dds_prl_addr     <= jam_dds_addr;
                        dds_prl_data     <= jam_dds_dout;
                        
                        -- Write least significant half-word
                        dds_addr_out <= jam_dds_addr;
                        dds_data_out <= jam_dds_dout(15 downto 0);                        
                        
                        fsm_dds_parallel <= WR_1_1;         -- Jamming engine accesses are always write
                    elsif reg_dds_dout_valid_s = '1' then
                        -- The register accesses are based on the AD9914 6-bit "serial addresses"
                        -- We write the least significant half-word first and the DDS writes the addressed register
                        -- and the register below it in a 16-bit transfer so the 8-bit parallel address we require is
                        --     parallel_address = (serial_address * 4) + 1
                        -- Generate this by right-shifting by two bits & setting the LSB = 1
                        dds_prl_addr     <= reg_dds_addr_s & "01";
                        dds_prl_data     <= reg_dds_dout_s;
                        
                        -- Write least significant half-word
                        dds_addr_out <= reg_dds_addr_s & "01";
                        dds_data_out <= reg_dds_dout_s(15 downto 0);                        

                        -- Move to read/write state as requested
                        if reg_dds_rd_wr_n_s = '1' then
                            fsm_dds_parallel <= RD_1_1;
                        else
                            fsm_dds_parallel <= WR_1_1;
                        end if;
                    end if;

                -----------------
                -- WRITE CYCLE --
                -----------------
                when WR_1_1 =>
                    -- Write least significant half-word - setup period
                    fsm_dds_parallel <= WR_1_2;

                when WR_1_2 =>
                -- Write least significant half-word - write period
                    dds_wr_n         <= '0';
                    fsm_dds_parallel <= WR_1_3;

                when WR_1_3 =>
                    -- Write least significant half-word - hold period
                    dds_wr_n         <= '1';
                    fsm_dds_parallel <= WR_2_1;

                when WR_2_1 =>
                    -- Write most significant half-word
                    dds_data_out <= dds_prl_data(31 downto 16);
                    dds_addr_out <= std_logic_vector(unsigned(dds_prl_addr) + 2);
                    fsm_dds_parallel <= WR_2_2;

                when WR_2_2 =>
                    -- Write most significant half-word - setup period
                    fsm_dds_parallel <= WR_2_3;

                when WR_2_3 =>
                    -- Write most significant half-word - write period
                    dds_wr_n         <= '0';
                    fsm_dds_parallel <= WR_2_4;
                    
                when WR_2_4 =>
                    -- Write most significant half-word - hold period
                    dds_wr_n         <= '1';
                    fsm_dds_parallel <= IDLE;

                ----------------
                -- READ CYCLE --
                ----------------
                when RD_1_1 =>
                    -- Address significant half-word
                    dds_d_t          <= (others => '1');    -- Tri-state control: 1=input
                    dds_addr_out     <= dds_prl_addr;
                    fsm_dds_parallel <= RD_1_2;

                when RD_1_2 =>
                    dds_rd_n         <= '0';
                    fsm_dds_parallel <= RD_1_3;

                when RD_1_3 =>
                    fsm_dds_parallel <= RD_1_4;

                when RD_1_4 =>
                    fsm_dds_parallel <= RD_1_5;

                when RD_1_5 =>
                    fsm_dds_parallel <= RD_1_6;

                when RD_1_6 =>
                    fsm_dds_parallel <= RD_1_7;

                when RD_1_7 =>
                    fsm_dds_parallel <= RD_1_8;

                when RD_1_8 =>
                    fsm_dds_parallel <= RD_1_9;

                when RD_1_9 =>
                    fsm_dds_parallel <= RD_1_10;

                when RD_1_10 =>
                    fsm_dds_parallel <= RD_1_11;

                when RD_1_11 =>
                    fsm_dds_parallel <= RD_1_12;

                when RD_1_12 =>
                    fsm_dds_parallel <= RD_1_13;

                when RD_1_13 =>
                    fsm_dds_parallel <= RD_1_14;

                when RD_1_14 =>
                    fsm_dds_parallel <= RD_1_15;

                when RD_1_15 =>
                    -- Read least significant half-word
                    dds_din(15 downto 0) <= dds_data_in;
                    dds_rd_n         <= '1';
                    fsm_dds_parallel <= RD_1_16;

                when RD_1_16 =>
                    fsm_dds_parallel <= RD_1_17;

                when RD_1_17 =>
                    fsm_dds_parallel <= RD_1_18;

                when RD_1_18 =>
                    fsm_dds_parallel <= RD_1_19;

                when RD_1_19 =>
                    fsm_dds_parallel <= RD_1_20;

                when RD_1_20 =>
                    fsm_dds_parallel <= RD_1_21;

                when RD_1_21 =>
                    fsm_dds_parallel <= RD_1_22;

                when RD_1_22 =>
                    fsm_dds_parallel <= RD_1_23;

                when RD_1_23 =>
                    dds_d_t          <= (others => '0');    -- Tri-state control: 0=output
                    fsm_dds_parallel <= RD_2_1;


                when RD_2_1 =>
                    -- Address most significant half-word
                    dds_d_t          <= (others => '1');    -- Tri-state control: 1=input
                    dds_addr_out     <= std_logic_vector(unsigned(dds_prl_addr) + 2);
                    fsm_dds_parallel <= RD_2_2;

                when RD_2_2 =>
                    dds_rd_n     <= '0';
                    fsm_dds_parallel <= RD_2_3;

                when RD_2_3 =>
                    fsm_dds_parallel <= RD_2_4;

                when RD_2_4 =>
                    fsm_dds_parallel <= RD_2_5;

                when RD_2_5 =>
                    fsm_dds_parallel <= RD_2_6;

                when RD_2_6 =>
                    fsm_dds_parallel <= RD_2_7;

                when RD_2_7 =>
                    fsm_dds_parallel <= RD_2_8;

                when RD_2_8 =>
                    fsm_dds_parallel <= RD_2_9;

                when RD_2_9 =>
                    fsm_dds_parallel <= RD_2_10;

                when RD_2_10 =>
                    fsm_dds_parallel <= RD_2_11;

                when RD_2_11 =>
                    fsm_dds_parallel <= RD_2_12;

                when RD_2_12 =>
                    fsm_dds_parallel <= RD_2_13;

                when RD_2_13 =>
                    fsm_dds_parallel <= RD_2_14;

                when RD_2_14 =>
                    fsm_dds_parallel <= RD_2_15;

                when RD_2_15 =>
                    -- Read most significant half-word
                    dds_din(31 downto 16) <= dds_data_in;
                    dds_din_valid    <= '1';                -- Set data valid
                    dds_rd_n         <= '1';
                    fsm_dds_parallel <= RD_2_16;

                when RD_2_16 =>
                    fsm_dds_parallel <= RD_2_17;

                when RD_2_17 =>
                    fsm_dds_parallel <= RD_2_18;

                when RD_2_18 =>
                    fsm_dds_parallel <= RD_2_19;

                when RD_2_19 =>
                    fsm_dds_parallel <= RD_2_20;

                when RD_2_20 =>
                    fsm_dds_parallel <= RD_2_21;

                when RD_2_21 =>
                    fsm_dds_parallel <= RD_2_22;

                when RD_2_22 =>
                    fsm_dds_parallel <= RD_2_23;

                when RD_2_23 =>
                    dds_d_t          <= (others => '0');    -- Tri-state control: 0=output
                    dds_din_valid    <= '0';                -- Clear data valid
                    fsm_dds_parallel <= IDLE;
            end case;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Process which assigns DDS hardware control outputs from control register
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_dds_hw_out: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            drst            <= dds_ctrl_register(31);
            dds_ext_pwr_dwn <= dds_ctrl_register(1);
            dds_reset       <= dds_ctrl_register(0);
        end if;
    end process;

    p_duration: process (dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            if jam_en_n_s = '1' then
                -- Reset jam ready signal when in manual mode
                jam_start              <= '0';
                posn_adjust_acc        <= (others => '0');
                dds_duration_valid_r   <= '0';
                dds_duration_valid_rr  <= '0';
                dds_duration_valid_rrr <= '0';
            else
                dds_duration_valid_r   <= dds_duration_valid;
                dds_duration_valid_rr  <= dds_duration_valid_r;
                dds_duration_valid_rrr <= dds_duration_valid_rr;

                if jam_terminate_line = '1' then
                    jam_start <= '0';
                elsif dds_duration_valid = '1' then
                    -- Set jam ready signal when first duration is received to
                    -- kick-start jamming engine
                    io_update_next_dur <= unsigned(dds_duration) - 1;
                    jam_start <= '1';
                end if;

                if tp_sync_en = '1' then
                    -- Sync TP enabled
                    if posn_adjust_valid = '1' then
                        -- Load new position adjustment value
                        posn_adjust_acc <= posn_adjust;
                    elsif dds_duration_valid_rrr = '1' then
                        -- Apply position adjustment if this is a blanking line
                        -- or a jamming line with ADJUST ALLOW set
                        if rf_ctrl(9) = '1' or rf_ctrl(14) = '1' then
                            io_update_next_dur_adj <= io_update_next_dur_o;
                            posn_adjust_acc        <= posn_adjust_acc_o;
                        else
                            -- Not a blanking line - no adjustment
                            io_update_next_dur_adj <= io_update_next_dur;
                        end if;
                    end if;
                else
                    -- Sync TP disabled, no position adjustment
                    io_update_next_dur_adj <= io_update_next_dur;
                    posn_adjust_acc        <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    p_dur_acc_calc: process (dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            --==================--
            -- Pipeline Stage 1 --
            --==================--
            if posn_adjust_acc > C_POSN_ADJUST_MAX then
                posn_adjust_ltd <= C_POSN_ADJUST_MAX;
            else
                posn_adjust_ltd <= posn_adjust_acc;
            end if;

            --==================--
            -- Pipeline Stage 2 --
            --==================--
            io_update_next_comp    <= C_MIN_BLANK_PERIOD + posn_adjust_ltd;
            io_update_next_dur_inc <= io_update_next_dur + posn_adjust_ltd;
            io_update_next_dur_dec <= io_update_next_dur - posn_adjust_ltd;

            -- Accumulator subtrahend if minimum blank window size gets used
            posn_adjust_acc_sub    <= io_update_next_dur(posn_adjust_acc'range) + C_MIN_BLANK_PERIOD(posn_adjust_acc'range);

            --==================--
            -- Pipeline Stage 3 --
            --==================--
            if posn_inc_dec_n = '0' and (io_update_next_dur < io_update_next_comp) then
                io_update_use_min <= '1';
            else
                io_update_use_min <= '0';
            end if;

            --==================--
            -- Pipeline Stage 4 --
            --==================--
            if io_update_use_min = '0' then
                posn_adjust_acc_o <= posn_adjust_acc - posn_adjust_ltd;
                if posn_inc_dec_n = '1' then
                    -- Increment blank window
                    io_update_next_dur_o <= io_update_next_dur_inc;
                else
                    -- Decrement blank window
                    io_update_next_dur_o <= io_update_next_dur_dec;
                end if;
            else
                -- Use minimum blank window size
                io_update_next_dur_o <= C_MIN_BLANK_PERIOD;
                posn_adjust_acc_o    <= posn_adjust_acc - posn_adjust_acc_sub;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Process which re-registers io_update_req onto DDS sync clk and outputs io_update pulse
    --!
    --! @param[in]   dds_sync_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_io_update: process (dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            io_update_shift <= io_update_shift(io_update_shift'high-1 downto 0) & '0';

            if jam_en_n_s = '1' then
                -- Manual control mode
                if io_update_req_s = '1' then
                    io_update_shift <= (others => '1');
                end if;
            elsif jam_start = '1' then
                -- Jamming engine (auto) mode
                if io_update_hold = '1' then
                    -- Delay by 4 clocks before issuing update after hold is released to
                    -- allow DDS shadow register write to complete
                    io_update_count <= to_unsigned(4, io_update_count'length);
                elsif io_update_count = 0 then
                    -- Issue IO update and set timer to next value
                    io_update_shift <= (others => '1');
                    -- If capture flag is high then use the original duration
                    -- If capture flag is low then use the adjusted duration
                    if capture_position_flag = '1' then
                        io_update_count <= io_update_next_dur;
                    else
                        io_update_count <= io_update_next_dur_adj;
                    end if;
                else
                    io_update_count <= io_update_count - 1;
                end if;
            else
                -- Delay by 3 clocks before issuing update after start is asserted to
                -- allow DDS shadow register write to complete
                io_update_count <= to_unsigned(3, io_update_count'length);            
            end if;

            -- Drive the DDS io_update output and set the update flag which gets re-registered
            -- onto reg_clk to send back to the jamming engine controller
            update_flag <= io_update_shift(io_update_shift'high);
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Process which latches the blank action flag from the jamming line
    --! control word
    --!
    --! @param[in]   dds_sync_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_blank_action: process (dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            if jam_en_n_s = '1' then
                blank_action   <= C_BLANK_CONTINUE;
                sequence_start <= '0';
                sol_blank_n    <= '1';
                sol_timer      <= (others => '0');
                rf_ctrl_prev   <= (others => '0');
                dds_ftw_prev   <= (others => '0');
            else
                -- Default
                sequence_start <= '0';

                -- Start of line timer
                if sol_timer > 0 then
                    sol_timer <= sol_timer - 1;
                else
                    -- Release start of line blanking
                    sol_blank_n <= '1';
                end if;

                if update_flag = '1' then
                    rf_ctrl_prev   <= rf_ctrl;
                    dds_ftw_prev   <= dds_ftw_latest;
                    sequence_start <= rf_ctrl(8) and (not sequence_start);

                    -- Decide whether or not to perform start-of-line blanking:
                    --  If unit is low-band: no start-of-line blanking applied
                    --	Else if DDS frequency and RF Control word don’t change: no start-of-line blanking applied
                    --	Else [if DDS frequency or RF Control word do change]: start-of-line blanking applied
                    if unsigned(dgtr_id) /= "1111" and unsigned(rf_ctrl)      /= unsigned(rf_ctrl_prev) 
                                                   and unsigned(dds_ftw_prev) /= unsigned(dds_ftw_latest) then
                        sol_blank_n <= '0';
                        sol_timer   <= C_SOL_BLANK_TIME;
                    end if;

                    if reload_next_line = '0' then
                        -- Register the blank action for the line that is being activated in the DDS
                        blank_action          <= rf_ctrl(11 downto 10);

                        -- Register the details for the line that is being activated in the DDS
                        rf_ctrl_store(0)      <= rf_ctrl_store(1);
                        dds_ftw_store(0)      <= dds_ftw_store(1);
                        dds_dftw_store(0)     <= dds_dftw_store(1);
                        dds_asf_pow_store(0)  <= dds_asf_pow_store(1);
                        dds_duration_store(0) <= dds_duration_store(1);
                    end if;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Register the RF control bits for the active jamming line
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_rf_ctrl: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if jam_en_n = '1' then
                rf_ctrl_s_r       <= (others => '0');
                jam_rf_ctrl_valid <= '0';
                vswr_line_start   <= '0';
                jam_blank_out_n   <= '1';
            else
                rf_ctrl_s_r <= rf_ctrl_s;
                jam_rf_ctrl <= rf_ctrl_s_r;

                if update_flag_s = '1' then
                    jam_rf_ctrl_valid <= '1';
                    vswr_line_start   <= rf_ctrl_s(31);
                    jam_blank_out_n   <= not rf_ctrl_s(9);
                else
                    jam_rf_ctrl_valid <= '0';
                    vswr_line_start   <= '0';
                end if;
            end if;
        end if;
    end process;

    p_dds_sweep: process(dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            if jam_en_n_s = '1' or jam_terminate_line = '1' then
                dds_sweep_rdy <= '1';
            elsif update_flag = '1' then
                dds_sweep_rdy <= '1';
            elsif dds_duration_valid = '1' then
                dds_sweep_rdy <= '0';
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Process which outputs OSK (mute) signal to DDS
    --!
    --! @param[in]   dds_sync_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_osk: process (dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            if jam_en_n_s = '1' then
                dds_mute_n  <= '1';
                dds_osk     <= '1';
            else
                if tp_sync_en = '0' then
                    -- Assert DDS blanking if we are preparing for a restart
                    if dds_restart_prep_s = '1' then
                        dds_mute_n <= '0';
                    -- Release DDS blanking when IO Update is issued or if we are on a "continue line"
                    elsif unsigned(blank_action) = unsigned(C_BLANK_CONTINUE) or update_flag = '1' then
                        dds_mute_n <= '1';
                    end if;
                else
                    -- Do not mute in synchronous TP mode (the mute will be built into the jamming lines)
                    dds_mute_n <= '1';
                end if;

                -- Output active-low blanking signal on OSK pin
                dds_osk <= blank_in_n_s and dds_mute_n and sol_blank_n;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Process which outputs drctl pulse
    --!
    --! @param[in]   dds_sync_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_drctl: process (dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            if jam_en_n_s = '0' then
                dds_dr_ctl   <= '1';
            else
                if drctl_req_s = '1' or dds_dr_over = '1' then
                    drctl_shift <= (others => '1');
                else
                    drctl_shift <= drctl_shift(drctl_shift'high-1 downto 0) & '0';
                end if;

                dds_dr_ctl <= drctl_shift(drctl_shift'high);
            end if;
        end if;
    end process;

    p_sync_clk_count: process (dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            sync_clk_count <= sync_clk_count + 1;

            -- Register the re-synchronised one second sync signal so that we can look
            -- at its previous value in this clock domain
            one_sec_sync_s_r <= one_sec_sync_s;

            if one_sec_sync_s_r = '0' and one_sec_sync_s = '1' then
                sync_clk_tick <= not sync_clk_tick;
                sync_clk_hold <= std_logic_vector(sync_clk_count);
                sync_clk_count <= to_unsigned(1, sync_clk_count'length);
            end if;
        end if;
    end process;

    p_pps_posn: process(dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            if jam_en_n_s = '1' then
                int_pps_s_r            <= '0';
                capture_position_flag  <= '0';
                first_capture          <= '1';
                pps_posn_cnt           <= C_PPS_POSN_CNT_MIN;
                pps_posn_err_valid     <= '0';
            else
                -- Default
                pps_posn_err_valid <= '0';

                -- Register the re-synchronised internal 1PPS so that we can look
                -- at its previous value in this clock domain
                int_pps_s_r <= int_pps_s;

                -- Reset counter to 0 when internal PPS rising edge is detected
                if int_pps_s_r = '0' and int_pps_s = '1' then
                    pps_posn_cnt <= (others => '0');

                    -- Log the position error of the most recent first mission line,
                    -- which could be on this cycle
                    if sequence_start = '1' then
                        -- Use value now
                        pps_posn_err_lo <= pps_posn_cnt;
                    else
                        -- Use logged value
                        pps_posn_err_lo <= pps_posn_err;
                    end if;

                    -- Set flag to capture the next position error
                    capture_position_flag <= '1';
                else
                    if pps_posn_cnt >= C_PPS_POSN_CNT_MAX then
                        pps_posn_cnt <= C_PPS_POSN_CNT_MIN;
                    else
                        pps_posn_cnt <= pps_posn_cnt + 1;
                    end if;
                end if;

                -- Capture count value when the first line in the sequence is activated
                if sequence_start = '1' then
                    pps_posn_err <= pps_posn_cnt;

                    -- Log the position error of the first line following the 1PPS event
                    if capture_position_flag = '1' then
                        first_capture          <= '0';
                        pps_posn_err_hi        <= pps_posn_cnt;
                        capture_position_flag  <= '0';
                        pps_posn_err_valid     <= not first_capture;
                    end if;
                end if;
            end if;
        end if;
    end process;

    p_pps_err_calc: process(dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            --==================--
            -- Pipeline Stage 1 --
            --==================--
            -- pps_posn_err_valid

            --==================--
            -- Pipeline Stage 2 --
            --==================--
            -- Calculate absolutes
            if pps_posn_err_lo(pps_posn_err_lo'high) = '1' then
                pps_posn_err_lo_abs <= (not pps_posn_err_lo) + 1;
            else
                pps_posn_err_lo_abs <= pps_posn_err_lo;
            end if;

            if pps_posn_err_hi(pps_posn_err_hi'high) = '1' then
                pps_posn_err_hi_abs <= (not pps_posn_err_hi) + 1;
            else
                pps_posn_err_hi_abs <= pps_posn_err_hi;
            end if;

            --==================--
            -- Pipeline Stage 3 --
            --==================--
            -- Which absolute error is the smallest?
            -- High-side error should be positive, otherwise counter is out of sync
            -- Low-side error should be negative, otherwise counter is out of sync
            if pps_posn_err_lo_abs < pps_posn_err_hi_abs then
                -- Low side error is the smallest, if it is negative (as it should be) or zero then use it
                if pps_posn_err_lo(pps_posn_err_lo'high) = '1' or pps_posn_err_lo = 0 then
                    pps_err_sel <= '0';
                else
                    -- Low-side error is positive, PPS counter out of sync, use high-side error
                    pps_err_sel <= '1';
                end if;
            else
                -- High side error is the smallest, if it is positive (as it should be) then use it
                if pps_posn_err_hi(pps_posn_err_lo'high) = '0' then
                    pps_err_sel <= '1';
                else
                    -- High-side error is negative, PPS counter out of sync, use low-side error
                    pps_err_sel <= '0';
                end if;
            end if;

            --==================--
            -- Pipeline Stage 4 --
            --==================--
            -- What is the sense of the selected error?
            -- Low-side  -> increment delay ('1')
            -- High-side -> decrement delay ('0')
            if pps_err_sel = '0' then
                -- Use low-side error
                posn_inc_dec_n <= '1';
                posn_adjust    <= unsigned(pps_posn_err_lo_abs(posn_adjust'range));
            else
                -- Use high-side error
                posn_inc_dec_n <= '0';
                posn_adjust    <= unsigned(pps_posn_err_hi_abs(posn_adjust'range));
            end if;
        end if;
    end process;

    p_reg_clk_count: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            -- Count register clock
            reg_clk_count <= reg_clk_count + 1;

            -- 80*10^6 clocks = one second
            if reg_clk_count = to_unsigned(79999999, 27) then
                reg_clk_count <= (others => '0');
                one_sec_sync  <= '1';
            else
                one_sec_sync  <= '0';
            end if;
        end if;
    end process;

    p_sync_clk_detect: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                sync_clk_detect  <= '0';
                sync_clk_tick_sr <= (others => '0');
            else
                -- Each time we count to one second in the reg_clk domain, shift in the synchronised
                -- sync_clk_tick signal which itself should be toggling every second. Note, however,
                -- that it is being toggled in another clock domain so we look for 3 consecutive
                -- unchanged values before deciding the clock is not there.
                if one_sec_sync = '1' then
                    sync_clk_tick_sr <= sync_clk_tick_sr(1 downto 0) & sync_clk_tick_s;
                end if;

                if sync_clk_tick_sr = "000" or sync_clk_tick_sr = "111" then
                    sync_clk_detect <= '0';
                else
                    sync_clk_detect <= '1';
                end if;
            end if;
        end if;
    end process;

    dds_ps <= "000"; -- DDS profile 1

    -----------------------------------------------------------------------------
    --! @brief PPS position error to position adjust pipeline delay
    -----------------------------------------------------------------------------
    i_delay_cnt_err_lim_valid: entity work.slv_delay
    generic map (
        bits    => 1,
        stages  => 3

    )
    port map (
        clk	    => dds_sync_clk,
        i(0)	=> pps_posn_err_valid,
        o(0)    => posn_adjust_valid
    );

    --------------------------------------
    -- Cross-clock domain synchronisers --
    --------------------------------------
    -- Register onto dds_sync_clk
    i_synchroniser_dds_dout: entity work.slv_synchroniser
    generic map (bits => reg_dds_dout'length,  sync_reset => false)
    port map (rst => drst, clk => dds_sync_clk, din => reg_dds_dout, dout => reg_dds_dout_s);

    i_synchroniser_dds_addr: entity work.slv_synchroniser
    generic map (bits => reg_dds_addr'length,  sync_reset => false)
    port map (rst => drst, clk => dds_sync_clk, din => reg_dds_addr, dout => reg_dds_addr_s);

    i_synchroniser_dds_dout_valid: entity work.slv_synchroniser
    generic map (bits => 1,  sync_reset => false)
    port map (rst => drst, clk => dds_sync_clk, din(0) => reg_dds_dout_valid, dout(0) => reg_dds_dout_valid_s);

    i_synchroniser_dds_dds_rd_wr_n: entity work.slv_synchroniser
    generic map (bits => 1,  sync_reset => false)
    port map (rst => drst, clk => dds_sync_clk, din(0) => reg_dds_rd_wr_n, dout(0) => reg_dds_rd_wr_n_s);

    i_synchroniser_io_update_req: entity work.slv_synchroniser
    generic map (bits => 1,  sync_reset => false)
    port map (rst => drst, clk => dds_sync_clk, din(0) => io_update_req, dout(0) => io_update_req_s);

    i_synchroniser_jam_en_n: entity work.slv_synchroniser
    generic map (bits => 1,  sync_reset => false)
    port map (rst => drst, clk => dds_sync_clk, din(0) => jam_en_n, dout(0) => jam_en_n_s);

    i_synchroniser_drctl_req: entity work.slv_synchroniser
    generic map (bits => 1,  sync_reset => false)
    port map (rst => drst, clk => dds_sync_clk, din(0) => drctl_req, dout(0) => drctl_req_s);

    i_synchroniser_dds_restart_prep: entity work.slv_synchroniser
    generic map (bits => 1,  sync_reset => false)
    port map (rst => drst, clk => dds_sync_clk, din(0) => dds_restart_prep, dout(0) => dds_restart_prep_s);

    i_synchroniser_dds_restart_exec: entity work.slv_synchroniser
    generic map (bits => 1,  sync_reset => false)
    port map (rst => drst, clk => dds_sync_clk, din(0) => dds_restart_exec, dout(0) => dds_restart_exec_s);

    i_synchroniser_one_sec_sync: entity work.slv_synchroniser
    generic map (bits => 1,  sync_reset => false)
    port map (rst => drst, clk => dds_sync_clk, din(0) => one_sec_sync, dout(0) => one_sec_sync_s);

    i_synchroniser_blank_in_n: entity work.slv_synchroniser
    generic map (bits => 1,  sync_reset => false)
    port map (rst => drst, clk => dds_sync_clk, din(0) => blank_in_n, dout(0) => blank_in_n_s);

    i_synchroniser_int_pps: entity work.slv_synchroniser
    generic map (bits => 1,  sync_reset => false)
    port map (rst => drst, clk => dds_sync_clk, din(0) => int_pps_i, dout(0) => int_pps_s);

    -- Register onto reg_clk
    i_synchroniser_dds_din: entity work.slv_synchroniser
    generic map (bits => dds_din'length,  sync_reset => true)
    port map (rst => reg_srst, clk => reg_clk, din => dds_din, dout => dds_din_s);

    i_synchroniser_dds_din_valid: entity work.slv_synchroniser
    generic map (bits => 1,  sync_reset => true)
    port map (rst => reg_srst, clk => reg_clk, din(0) => dds_din_valid, dout(0) => dds_din_valid_s);

    i_synchroniser_rf_ctrl: entity work.slv_synchroniser
    generic map (bits => rf_ctrl'length,  sync_reset => true)
    port map (rst => reg_srst, clk => reg_clk, din => rf_ctrl, dout => rf_ctrl_s);

    i_synchroniser_update_flag: entity work.slv_synchroniser
    generic map (bits => 1,  sync_reset => true)
    port map (rst => reg_srst, clk => reg_clk, din(0) => update_flag, dout(0) => update_flag_s);

    i_synchroniser_sync_clk_tick: entity work.slv_synchroniser
    generic map (bits => 1,  sync_reset => true)
    port map (rst => reg_srst, clk => reg_clk, din(0) => sync_clk_tick, dout(0) => sync_clk_tick_s);

    i_synchroniser_sync_clk_hold: entity work.slv_synchroniser
    generic map (bits => sync_clk_hold'length,  sync_reset => true)
    port map (rst => reg_srst, clk => reg_clk, din => sync_clk_hold, dout => sync_clk_hold_s);

    ----------------
    -- IO Buffers --
    ----------------
    gen_dds_obuf: for i in 0 to 15 generate
        i_obuf: obuf port map (I => dds_d_out(i), O => dds_d(i));
    end generate;

    gen_dds_iobuf: for i in 16 to 31 generate
        i_iobuf: iobuf port map (I => dds_d_out(i), O => dds_d_in(i), T => dds_d_t(i), IO => dds_d(i));
    end generate;

end rtl;


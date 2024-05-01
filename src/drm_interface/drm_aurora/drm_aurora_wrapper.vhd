----------------------------------------------------------------------------------
--! @file drm_aurora_wrapper.vhd
--! @brief Module which instantiates the Xilinx Aurora core
--!
--! The Aurora core is a full-duplex module which provides bi-directional data
--! between the Source Board and the Digital Receiver Module.
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

library unisim;
use unisim.vcomponents.all;

----------------------------------------------------------------------------------
--! @brief Module which instantiates the Xilinx Aurora core
----------------------------------------------------------------------------------
entity drm_aurora_wrapper is
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        
        -- ECM Register Bus
        reg_mosi            : in reg_mosi_type;                     --! ECM register master-out, slave-in signals
        reg_miso            : out reg_miso_type;                    --! ECM register master-in, slave-out signals
        
        -- GTP Clock
        mgt_clk_p           : in std_logic;
        mgt_clk_n           : in std_logic;
        
        -- Aurora User Clock
        user_clk_o          : out std_logic;
        link_srst_o         : out std_logic;
        
        -- LocalLink Tx Interface
        tx_d                : in std_logic_vector(31 downto 0);
        tx_rem              : in std_logic_vector(0 to 1);
        tx_src_rdy_n        : in std_logic;
        tx_sof_n            : in std_logic;
        tx_eof_n            : in std_logic;
        tx_dst_rdy_n        : out std_logic;

        -- LocalLink Rx Interface
        rx_d                : out std_logic_vector(31 downto 0);
        rx_rem              : out std_logic_vector(0 to 1);
        rx_src_rdy_n        : out std_logic;
        rx_sof_n            : out std_logic;
        rx_eof_n            : out std_logic;

        -- GT I/O
        mgt_rx_p            : in std_logic;
        mgt_rx_n            : in std_logic;
        mgt_tx_p            : out std_logic;
        mgt_tx_n            : out std_logic;
        
        channel_up_o        : out std_logic
    );
end drm_aurora_wrapper;

architecture rtl of drm_aurora_wrapper is
    ----------------------------
    -- ATTRIBUTE DECLARATIONS --
    ----------------------------
	 attribute keep : string;
	 
	 ---------------------------
    -- CONSTANT DECLARATIONS --
    ---------------------------
    
    --------------------------------
    -- SIGNAL & TYPE DECLARATIONS --
    --------------------------------
    -- Clocks
    signal mgt_clk         : std_logic;
    signal mgt_clk_out     : std_logic;
    signal mgt_clk_out_buf : std_logic;
    signal user_clk        : std_logic;
    signal sync_clk        : std_logic;
	 
	attribute keep of user_clk : signal is "true";
	attribute keep of sync_clk : signal is "true";
    
    -- Resets
    signal rst_gt          : std_logic;
    signal rst_aur         : std_logic;
    signal rst_cc          : std_logic;
    signal rst_sys         : std_logic;
    
    signal rst_gt_shift    : std_logic_vector(3 downto 0);
    signal rst_aur_shift   : std_logic_vector(7 downto 0);
       
    -- Lock signals
    signal mgt_clk_locked  : std_logic;
    signal pll_locked      : std_logic;
    
    -- Core control/status   
    signal power_down      : std_logic;
    signal rx_eq_mix       : std_logic_vector(1 downto 0);
    signal tx_diff_ctrl    : std_logic_vector(3 downto 0);
    signal tx_preemphasis  : std_logic_vector(2 downto 0);
    signal hard_err        : std_logic;
    signal soft_err        : std_logic;
    signal frame_err       : std_logic;
    signal lane_up         : std_logic;
    signal channel_up      : std_logic;
    
    -- Clock Compensation Control Interface
    signal warn_cc         : std_logic;
    signal do_cc           : std_logic;
    
    signal err_count       : std_logic_vector(7 downto 0);
    signal rx_count        : std_logic_vector(31 downto 0);
    
    signal soft_err_latch  : std_logic;
    signal hard_err_latch  : std_logic;
    signal frame_err_latch : std_logic;
    signal reset_errors    : std_logic;
begin
    ------------------------
    -- SIGNAL ASSIGNMENTS --
    ------------------------
    user_clk_o   <= user_clk;
    link_srst_o  <= not channel_up;
    rst_cc       <= not lane_up;
    rst_sys      <= rst_aur_shift(0) or (not pll_locked);
    channel_up_o <= channel_up;
    
    -----------------------------
    -- COMBINATORIAL PROCESSES --
    -----------------------------

    --------------------------
    -- SEQUENTIAL PROCESSES --
    --------------------------
    -----------------------------------------------------------------------------
    --! @brief Register read/write process, synchronous to reg_clk.
    --!
    --! Handles TP registers
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_reg_rd_wr: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                -- Synchronous Reset
                reg_miso.ack   <= '0';
                reg_miso.data  <= (others => '0');
                rst_gt         <= '0';
                rst_aur        <= '0';
                power_down     <= '0';
                reset_errors   <= '1';
                rx_eq_mix      <= "00";
                tx_diff_ctrl   <= "1001";
                tx_preemphasis <= "000";
            else
                -- Defaults    
                reg_miso.ack  <= '0';
                reg_miso.data <= (others => '0');
                reset_errors  <= '0';

                if reg_mosi.valid = '1' then  
                    -- Control Register
                    if reg_mosi.addr = REG_ADDR_AURORA_CONTROL then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read                           
                            
                            -- Nibble 7
                            -- reg_miso.data(31:28) not used
                            
                            -- Nibble 6
                            -- reg_miso.data(27) not used
                            reg_miso.data(26) <= frame_err_latch;
                            reg_miso.data(25) <= soft_err_latch;
                            reg_miso.data(24) <= hard_err_latch;
                            
                            -- Nibble 5
                            -- reg_miso.data(23) not used
                            reg_miso.data(22) <= frame_err;
                            reg_miso.data(21) <= soft_err;
                            reg_miso.data(20) <= hard_err;
                            
                            -- Nibble 4
                            -- reg_miso.data(19) not used
                            reg_miso.data(18) <= mgt_clk_locked;
                            reg_miso.data(17) <= channel_up;
                            reg_miso.data(16) <= lane_up;
                            
                            -- Nibble 3
                            reg_miso.data(15 downto 12) <= tx_diff_ctrl;
                            
                            -- Nibble 2
                            -- reg_miso.data(11) not used
                            reg_miso.data(10 downto 8) <= tx_preemphasis;
                            
                            -- Nibble 1
                            -- reg_miso.data(7:6) not used
                            reg_miso.data(5 downto 4) <= rx_eq_mix;
                            
                            -- Nibble 0
                            -- reg_miso.data(3) not used
                            reg_miso.data(2) <= power_down;
                            reg_miso.data(1) <= rst_aur;
                            reg_miso.data(0) <= rst_gt;
                        else
                            -- Write
                            -- Nibble 3
                            tx_diff_ctrl <= reg_mosi.data(15 downto 12);
                            
                            -- Nibble 2
                            -- reg_mosi.data(11) not used
                            tx_preemphasis <= reg_mosi.data(10 downto 8);
                            
                            -- Nibble 1
                            reset_errors <= reg_mosi.data(7);
                            -- reg_mosi.data(6) not used
                            rx_eq_mix    <= reg_mosi.data(5 downto 4);
                            
                            -- Nibble 0
                            -- reg_mosi.data(3) not used
                            power_down   <= reg_mosi.data(2);
                            rst_aur      <= reg_mosi.data(1);
                            rst_gt       <= reg_mosi.data(0);                            
                        end if;
                        reg_miso.ack <= '1';
                    elsif reg_mosi.addr = REG_ADDR_AURORA_RX_COUNT then
                        if reg_mosi.rd_wr_n = '1' then
                            -- Read
                            reg_miso.data <= err_count & rx_count(23 downto 0);
                            reg_miso.ack  <= '1';    
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------------------
    --! @brief Reset aurora/gt
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_rst_aur: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                -- Synchronous Reset
                rst_gt_shift   <= (others => '1');
                rst_aur_shift  <= (others => '1');
            else
                if rst_gt = '1' then
                    rst_gt_shift <= (others => '1');
                else
                    rst_gt_shift <= '0' & rst_gt_shift(rst_gt_shift'length-1 downto 1);
                end if;
                
                if rst_aur = '1' then
                    rst_aur_shift <= (others => '1');
                else
                    rst_aur_shift <= '0' & rst_aur_shift(rst_aur_shift'length-1 downto 1);
                end if;
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------------------
    --! @brief Register read/write process, synchronous to reg_clk.
    --!
    --! Latches errors
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_err_latch: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reset_errors = '1' then
                -- Synchronous Reset
                soft_err_latch  <= '0';
                hard_err_latch  <= '0';
                frame_err_latch <= '0';
            else
                if soft_err = '1' then
                    soft_err_latch <= '1';
                end if;
                
                if hard_err = '1' then
                    hard_err_latch <= '1';
                end if;
                
                if frame_err = '1' then
                    frame_err_latch <= '1';
                end if;
            end if;
        end if;
    end process;
    
    ---------------------------
    -- ENTITY INSTANTIATIONS --
    ---------------------------
    -- Clock Buffers
    i_ibufds:  ibufds port map (I => mgt_clk_p, IB => mgt_clk_n, O => mgt_clk);

    i_bufio2: bufio2 generic map (DIVIDE => 1,           DIVIDE_BYPASS => TRUE)
                        port map (I      => mgt_clk_out, DIVCLK        => mgt_clk_out_buf,
                                  IOCLK  => open,        SERDESSTROBE  => open);
    
    -- Instantiate a clock module for clock division
    i_clock_module: entity work.drm_aurora_clock_module
    port map (
        mgt_clk        => mgt_clk_out_buf,
        mgt_clk_locked => mgt_clk_locked,
        user_clk       => user_clk,
        sync_clk       => sync_clk,
        pll_locked     => pll_locked
    );    
    
    -- Instantiate the Clock Compensation module
    i_drm_aurora_cc_module: entity work. drm_aurora_cc_module
    port map (    
        -- Clock Compensation Control Interface
        warn_cc        => warn_cc,
        do_cc          => do_cc,

        -- System Interface
        user_clk       => user_clk,
        reset          => rst_cc
    );
    
    -- Instantiate the Aurora Module
    i_drm_aurora: entity work.drm_aurora
    generic map (
        SIM_GTPRESET_SPEEDUP => 1
    )
    port map (
        -- LocalLink Tx Interface
        TX_D           => tx_d,
        TX_REM         => tx_rem,
        TX_SRC_RDY_N   => tx_src_rdy_n,
        TX_SOF_N       => tx_sof_n,
        TX_EOF_N       => tx_eof_n,
        TX_DST_RDY_N   => tx_dst_rdy_n,

        -- LocalLink Rx Interface
        RX_D           => rx_d,
        RX_REM         => rx_rem,
        RX_SRC_RDY_N   => rx_src_rdy_n,
        RX_SOF_N       => rx_sof_n,
        RX_EOF_N       => rx_eof_n,

        -- MGT Serial I/O
        RXP            => mgt_rx_p,
        RXN            => mgt_rx_n,
        TXP            => mgt_tx_p,
        TXN            => mgt_tx_n,

        -- MGT Reference Clock Interface
        GTPD0          => mgt_clk,

        -- Error Detection Interface
        HARD_ERR       => hard_err,
        SOFT_ERR       => soft_err,
        FRAME_ERR      => frame_err,

        -- Status
        CHANNEL_UP     => channel_up,
        LANE_UP        => lane_up,

        -- Clock Compensation Control Interface
        WARN_CC        => warn_cc,
        DO_CC          => do_cc,

        -- System Interface
        USER_CLK       => user_clk,
        SYNC_CLK       => sync_clk,
        RESET          => rst_sys,
        POWER_DOWN     => power_down,
        LOOPBACK       => "000",
        GT_RESET       => rst_gt_shift(0),
        GTPCLKOUT      => mgt_clk_out,
        RXEQMIX_IN     => rx_eq_mix,
        TX_DIFF_CTRL   => tx_diff_ctrl,
        TX_PREEMPHASIS => tx_preemphasis,
        DADDR_IN       => x"00",
        DCLK_IN        => '0',
        DEN_IN         => '0',
        DI_IN          => x"0000",
        DRDY_OUT       => open,
        DRPDO_OUT      => open,
        DWE_IN         => '0',
        TX_LOCK        => mgt_clk_locked
    );    
end rtl;
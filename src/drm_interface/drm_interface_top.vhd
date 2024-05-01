----------------------------------------------------------------------------------
--! @file drm_interface_top.vhd
--! @brief Module which interfaces the Digital Receiver Module
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

----------------------------------------------------------------------------------
--! @brief Module which interfaces the Digital Receiver Module
----------------------------------------------------------------------------------
entity drm_interface_top is
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset

        -- ECM Register Bus
        reg_mosi_ecm        : in reg_mosi_type;                     --! ECM register master-out, slave-in signals
        reg_miso_ecm        : out reg_miso_type;                    --! ECM register master-in, slave-out signals
                                                                    
        -- DRM Register Bus                                         
        reg_mosi_drm        : out reg_mosi_type;                    --! DRM register master-out, slave-in signals
        reg_miso_drm        : in reg_miso_type;                     --! DRM register master-in, slave-out signals
        
        -- MGT Clock
        mgt_clk_p           : in std_logic;
        mgt_clk_n           : in std_logic;

        -- MGT I/O
        mgt_rx_p            : in std_logic;
        mgt_rx_n            : in std_logic;
        mgt_tx_p            : out std_logic;
        mgt_tx_n            : out std_logic;
        
        channel_up_o        : out std_logic
    );
end drm_interface_top;

architecture rtl of drm_interface_top is
    ---------------------------
    -- CONSTANT DECLARATIONS --
    ---------------------------
    
    --------------------------------
    -- SIGNAL & TYPE DECLARATIONS --
    --------------------------------
    -- Aurora core clock/reset out
    signal user_clk        : std_logic;
    signal link_srst       : std_logic;
    
    -- Aurora core status
    signal channel_up      : std_logic;
    
    -- LocalLink Tx Interface
    signal tx_d            : std_logic_vector(31 downto 0);
    signal tx_rem          : std_logic_vector(0 to 1);
    signal tx_src_rdy_n    : std_logic;
    signal tx_sof_n        : std_logic;
    signal tx_eof_n        : std_logic;
    signal tx_dst_rdy_n    : std_logic;

    -- LocalLink Rx Interface
    signal rx_d            : std_logic_vector(31 downto 0);
    signal rx_rem          : std_logic_vector(0 to 1);
    signal rx_src_rdy_n    : std_logic;
    signal rx_sof_n        : std_logic;
    signal rx_eof_n        : std_logic;
    
    -- Register mux signals
    signal reg_miso_wrap   : reg_miso_type;
    signal reg_miso_bridge : reg_miso_type;
    signal reg_miso_dummy  : reg_miso_type;
begin
    ------------------------
    -- SIGNAL ASSIGNMENTS --
    ------------------------
    channel_up_o        <= channel_up;
    reg_miso_dummy.data <= (others => '0');
    reg_miso_dummy.ack  <= '0';
    
    -----------------------------
    -- COMBINATORIAL PROCESSES --
    -----------------------------
    
    --------------------------
    -- SEQUENTIAL PROCESSES --
    --------------------------
    
    ---------------------------
    -- ENTITY INSTANTIATIONS --
    ---------------------------
    -- Instantiate frame generator
    --i_drm_aurora_frame_gen: entity work.drm_aurora_frame_gen
    --port map (
    --    -- User Interface
    --    TX_D            => tx_d,
    --    TX_REM          => tx_rem,
    --    TX_SOF_N        => tx_sof_n,
    --    TX_EOF_N        => tx_eof_n,
    --    TX_SRC_RDY_N    => tx_src_rdy_n,
    --    TX_DST_RDY_N    => tx_dst_rdy_n,
    --
    --    -- System Interface
    --    USER_CLK        => user_clk,
    --    RESET           => rst_sys,
    --    CHANNEL_UP      => channel_up
    --);
    
    ---- Instantiate frame checker
    --i_drm_aurora_frame_check: entity work.drm_aurora_frame_check
    --port map (
    --    -- User Interface
    --    RX_D            => rx_d,
    --    RX_REM          => rx_rem,
    --    RX_SOF_N        => rx_sof_n,
    --    RX_EOF_N        => rx_eof_n,
    --    RX_SRC_RDY_N    => rx_src_rdy_n,
    --
    --    -- System Interface
    --    USER_CLK        => user_clk,
    --    RESET           => rst_sys,
    --    CHANNEL_UP      => channel_up,
    --    ERR_COUNT       => err_count,
    --    RX_COUNT        => rx_count
    --);
    
    ----------------------------------------------------------------------------------
    --! @brief Module briding ECM register buses to DRM via the Aurora core
    ----------------------------------------------------------------------------------
    i_drm_reg_bridge: entity work.drm_reg_bridge
    port map (
        -- Register Buses
        reg_clk         => reg_clk,
        reg_srst        => reg_srst,
        slv_reg_mosi    => reg_mosi_ecm,
        slv_reg_miso    => reg_miso_bridge,
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
    
    ----------------------------------------------------------------------------------
    --! @brief Wrapper providing the Aurora core and a register interface to read its status
    ----------------------------------------------------------------------------------
    i_drm_aurora_wrapper: entity work.drm_aurora_wrapper
    port map (
        -- Register Bus
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_mosi            => reg_mosi_ecm,
        reg_miso            => reg_miso_wrap,
        
        -- GTP Clock
        mgt_clk_p           => mgt_clk_p,
        mgt_clk_n           => mgt_clk_n,
        
        -- Aurora User Clock
        user_clk_o          => user_clk,
        link_srst_o         => link_srst,
        
        -- LocalLink Tx Interface
        tx_d                => tx_d,
        tx_rem              => tx_rem,
        tx_src_rdy_n        => tx_src_rdy_n,
        tx_sof_n            => tx_sof_n,
        tx_eof_n            => tx_eof_n,
        tx_dst_rdy_n        => tx_dst_rdy_n,

        -- LocalLink Rx Interface
        rx_d                => rx_d,
        rx_rem              => rx_rem,
        rx_src_rdy_n        => rx_src_rdy_n,
        rx_sof_n            => rx_sof_n,
        rx_eof_n            => rx_eof_n,

        -- GT I/O
        mgt_rx_p            => mgt_rx_p,
        mgt_rx_n            => mgt_rx_n,
        mgt_tx_p            => mgt_tx_p,
        mgt_tx_n            => mgt_tx_n,
        
        -- Channel Up
        channel_up_o        => channel_up
    );
    
    ----------------------------------------------------------------------------------
    --! @brief Register multiplexer
    ----------------------------------------------------------------------------------
    i_reg_miso_mux: entity work.reg_miso_mux6
    port map (
        -- Clock
        reg_clk             => reg_clk,

        -- Input data/valid
        reg_miso_i_1        => reg_miso_wrap,
        reg_miso_i_2        => reg_miso_bridge,
        reg_miso_i_3        => reg_miso_dummy,
        reg_miso_i_4        => reg_miso_dummy,
        reg_miso_i_5        => reg_miso_dummy,
        reg_miso_i_6        => reg_miso_dummy,

        -- Output data/valid
        reg_miso_o          => reg_miso_ecm
    );
end rtl;
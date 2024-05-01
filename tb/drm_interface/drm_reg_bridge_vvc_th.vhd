library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library uvvm_vvc_framework;
use uvvm_vvc_framework.ti_vvc_framework_support_pkg.all;

library bitvis_vip_reg;
use bitvis_vip_reg.reg_bfm_pkg.all;

library bitvis_vip_locallink;
use bitvis_vip_locallink.locallink_bfm_pkg.all;

library drm_interface;
use drm_interface.drm_reg_bridge_vvc_pkg.all;
use drm_interface.reg_pkg.all;

-- Test harness entity
entity drm_reg_bridge_vvc_th is
end entity;

-- Test harness architecture
architecture struct of drm_reg_bridge_vvc_th is
    -- Constants    
    constant C_REG_ADDR_WIDTH : integer := 24;
    constant C_REG_DATA_WIDTH : integer := 32;
    constant C_LL_DATA_WIDTH  : integer := 32;
    
    -- Register clock/reset signals
    signal reg_clk        : std_logic := '0';
    signal reg_srst       : std_logic := '0';
    
    -- Link clock/reset signals
    signal link_clk       : std_logic := '0';
    signal link_srst      : std_logic := '0';

    -- Reg VVC signals    
    signal m_reg_if : t_reg_if(addr(C_REG_ADDR_WIDTH-1 downto 0),
                               rdata(C_REG_DATA_WIDTH-1 downto 0),
                               wdata(C_REG_DATA_WIDTH-1 downto 0));
                               
    -- LocalLink VVC signals
    signal m_locallink_if : t_locallink_if(data(C_LL_DATA_WIDTH-1 downto 0),
                                           remd(natural(log2(real(C_LL_DATA_WIDTH/8)))-1 downto 0));
    
    signal s_locallink_if : t_locallink_if(data(C_LL_DATA_WIDTH-1 downto 0),
                                           remd(natural(log2(real(C_LL_DATA_WIDTH/8)))-1 downto 0));
                                           
    -- Reg DUT signals
    signal s_reg_mosi : reg_mosi_type;
    signal s_reg_miso : reg_miso_type;
    signal m_reg_mosi : reg_mosi_type;
    signal m_reg_miso : reg_miso_type;
    
    -- General Registers signals
    signal ext_gpio : std_logic_vector(7 downto 0) := x"AA";

begin
	m_reg_mosi.data    <= m_reg_if.wdata;
    m_reg_mosi.addr    <= std_logic_vector(m_reg_if.addr);
    m_reg_mosi.valid   <= m_reg_if.valid;
    m_reg_mosi.rd_wr_n <= m_reg_if.rd_wr_n;
    m_reg_if.rdata     <= m_reg_miso.data;
    m_reg_if.ack       <= m_reg_miso.ack;
    
    -----------------------------------------------------------------------------
    -- Instantiate the concurrent procedure that initializes UVVM
    -----------------------------------------------------------------------------
    i_ti_uvvm_engine : entity uvvm_vvc_framework.ti_uvvm_engine;

    -----------------------------------------------------------------------------
    -- Instantiate DUT
    -----------------------------------------------------------------------------
    i_drm_reg_bridge: entity drm_interface.drm_reg_bridge
    port map (
        -- Register Buses
        reg_clk         => reg_clk,
        reg_srst        => reg_srst,
        slv_reg_mosi    => m_reg_mosi,
        slv_reg_miso    => m_reg_miso,
        reg_mosi_drm    => s_reg_mosi,
        reg_miso_drm    => s_reg_miso,

        -- Aurora User Clock
        user_clk        => link_clk,
        link_srst       => link_srst,

        -- LocalLink Tx Interface
        tx_d            => s_locallink_if.data,
        tx_rem          => s_locallink_if.remd,
        tx_src_rdy_n    => s_locallink_if.src_rdy_n,
        tx_sof_n        => s_locallink_if.sof_n,
        tx_eof_n        => s_locallink_if.eof_n,
        tx_dst_rdy_n    => s_locallink_if.dst_rdy_n,

        -- LocalLink Rx Interface
        rx_d            => m_locallink_if.data,
        rx_rem          => m_locallink_if.remd,
        rx_src_rdy_n    => m_locallink_if.src_rdy_n,
        rx_sof_n        => m_locallink_if.sof_n,
        rx_eof_n        => m_locallink_if.eof_n
    );
    
    -----------------------------------------------------------------------------
    -- Attach a General Registers object to the master reg interface so that 
    -- we can read it via bridge
    -----------------------------------------------------------------------------
    i_regs: entity drm_interface.general_registers
    port map (
        reg_clk   => reg_clk,
        reg_srst  => reg_srst,
        reg_mosi  => s_reg_mosi,
        reg_miso  => s_reg_miso,
        ext_gpio  => ext_gpio,
        hw_vers   => "101",
        hw_mod    => "010" 
    );

    -----------------------------------------------------------------------------
    -- Reg VVC
    -----------------------------------------------------------------------------
    i_reg_vvc_master: entity bitvis_vip_reg.reg_vvc
    generic map (
        GC_ADDR_WIDTH     => C_REG_ADDR_WIDTH,
        GC_DATA_WIDTH     => C_REG_DATA_WIDTH,
        GC_INSTANCE_IDX   => C_IDX_REG_MASTER
    )
    port map (
        clk => reg_clk,
        reg_vvc_master_if => m_reg_if
    );
    
    -----------------------------------------------------------------------------
    -- Local Link Master VVC
    -----------------------------------------------------------------------------
    i_locallink_master: entity bitvis_vip_locallink.locallink_vvc
    generic map (
        GC_VVC_IS_MASTER => true,
        GC_DATA_WIDTH    => C_LL_DATA_WIDTH,
        GC_INSTANCE_IDX  => C_IDX_LL_MASTER
    )
    port map (
        clk              => link_clk,
        locallink_vvc_if => m_locallink_if
    );
    
    -----------------------------------------------------------------------------
    -- Local Link Slave VVC
    -----------------------------------------------------------------------------
    i_locallink_slave: entity bitvis_vip_locallink.locallink_vvc
    generic map (
        GC_VVC_IS_MASTER => false,
        GC_DATA_WIDTH    => C_LL_DATA_WIDTH,
        GC_INSTANCE_IDX  => C_IDX_LL_SLAVE
    )
    port map (
        clk              => link_clk,
        locallink_vvc_if => s_locallink_if
    );
    
    -----------------------------------------------------------------------------
    -- Local Link Slave VVC
    -----------------------------------------------------------------------------
    
    -- Toggle the reset after 5 clock periods
    p_reg_srst:  reg_srst  <= '1', '0' after 5 * C_REG_CLK_PERIOD;
    p_link_srst: link_srst <= '1', '0' after 5 * C_LINK_CLK_PERIOD;
    
    -----------------------------------------------------------------------------
    -- Clock process
    -----------------------------------------------------------------------------
    p_reg_clk: process
    begin
        reg_clk <= '0', '1' after C_REG_CLK_PERIOD / 2;
        wait for C_REG_CLK_PERIOD;
    end process;
    
    p_link_clk: process
    begin
        link_clk <= '0', '1' after C_LINK_CLK_PERIOD / 2;
        wait for C_LINK_CLK_PERIOD;
    end process;    
end struct;

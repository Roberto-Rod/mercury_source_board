library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_vvc_framework;
use uvvm_vvc_framework.ti_vvc_framework_support_pkg.all;

library bitvis_vip_reg;
use bitvis_vip_reg.reg_bfm_pkg.all;

library general_registers;
use general_registers.reg_pkg.all;

-- Test harness entity
entity general_registers_vvc_th is
end entity;

-- Test harness architecture
architecture struct of general_registers_vvc_th is
    -- Constants    
    constant C_ADDR_WIDTH : integer := 24;
    constant C_DATA_WIDTH : integer := 32;
    
    -- Clock/reset signals
    signal reg_clk        : std_logic := '0';
    signal reg_srst       : std_logic := '0';

    -- Reg VVC signals    
    signal reg_if : t_reg_if(addr(C_ADDR_WIDTH-1 downto 0),
                             rdata(C_DATA_WIDTH-1 downto 0),
                             wdata(C_DATA_WIDTH-1 downto 0));
                             
    -- Reg DUT signals
    signal reg_mosi  : reg_mosi_type;    
    signal reg_miso  : reg_miso_type;

    -- Hardware version/mod-level
    signal hw_vers   : std_logic_vector(2 downto 0) := "010";
    signal hw_mod    : std_logic_vector(2 downto 0) := "101";
    
    -- External GPIO
    signal ext_gpio  : std_logic_vector(7 downto 0);
    
    constant C_CLK_PERIOD   : time := 16 ns; -- 80 MHz

begin
	reg_mosi.data    <= reg_if.wdata;
    reg_mosi.addr    <= std_logic_vector(reg_if.addr);
    reg_mosi.valid   <= reg_if.valid;
    reg_mosi.rd_wr_n <= reg_if.rd_wr_n;
    reg_if.rdata     <= reg_miso.data;
    reg_if.ack       <= reg_miso.ack;
    
    -----------------------------------------------------------------------------
    -- Instantiate the concurrent procedure that initializes UVVM
    -----------------------------------------------------------------------------
    i_ti_uvvm_engine : entity uvvm_vvc_framework.ti_uvvm_engine;

    -----------------------------------------------------------------------------
    -- Instantiate DUT
    -----------------------------------------------------------------------------
    i_general_registers: entity work.general_registers
    port map (
        reg_clk   => reg_clk,
        reg_srst  => reg_srst,
        reg_mosi  => reg_mosi,
        reg_miso  => reg_miso,
        ext_gpio  => ext_gpio,
        hw_vers   => hw_vers,
        hw_mod    => hw_mod 
    );


    -----------------------------------------------------------------------------
    -- Reg VVC
    -----------------------------------------------------------------------------
    i_reg_vvc: entity bitvis_vip_reg.reg_vvc
    generic map (
        GC_ADDR_WIDTH     => C_ADDR_WIDTH,
        GC_DATA_WIDTH     => C_DATA_WIDTH,
        GC_INSTANCE_IDX   => 1
    )
    port map (
        clk => reg_clk,
        reg_vvc_master_if => reg_if
    );

    -- Toggle the reset after 5 clock periods
    p_reg_srst: reg_srst  <= '1', '0' after 5 * C_CLK_PERIOD;

    -----------------------------------------------------------------------------
    -- Clock process
    -----------------------------------------------------------------------------
    p_reg_clk: process
    begin
        reg_clk <= '0', '1' after C_CLK_PERIOD / 2;
        wait for C_CLK_PERIOD;
    end process;
end struct;

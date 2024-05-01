library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library uvvm_util;
use uvvm_util.types_pkg.all;

package drm_reg_bridge_vvc_pkg is
    -- Clock period setting
    constant C_REG_CLK_PERIOD  : time := 12.5 ns; -- 80.000 MHz
    constant C_LINK_CLK_PERIOD : time := 64.0 ns; -- 15.625 MHz
    
    -- Reg VVC Indices
    constant C_IDX_REG_MASTER        : natural := 1;
    constant C_IDX_REG_SLAVE         : natural := 2;
    
    -- Local Link VVC Indices
    constant C_IDX_LL_MASTER         : natural := 1;
    constant C_IDX_LL_SLAVE          : natural := 2;
    
    -- Bridge Op Codes
    constant C_OP_READ       : std_logic_vector(7 downto 0) := x"00";
    constant C_OP_WRITE      : std_logic_vector(7 downto 0) := x"01";
    constant C_OP_READ_RESP  : std_logic_vector(7 downto 0) := x"02";    
    
    -- ECM register space addresses
    constant C_ADDR_DWG_NUMBER : unsigned(23 downto 0) := x"000001";
    constant C_ADDR_GPIO_DATA  : unsigned(23 downto 0) := x"000002";
    constant C_ADDR_GPIO_DIR   : unsigned(23 downto 0) := x"000003";
    constant C_ADDR_DRM_BASE   : unsigned(23 downto 0) := x"110000";
    
    function cmd_write (
        addr: in unsigned(23 downto 0);
        data: in std_logic_vector(31 downto 0)
    ) return t_byte_array;
    
    function cmd_read (
        addr: in unsigned(23 downto 0)
    ) return t_byte_array;
    
    function cmd_read_response (
        data: in std_logic_vector(31 downto 0)
    ) return t_byte_array;
    
end package drm_reg_bridge_vvc_pkg;

package body drm_reg_bridge_vvc_pkg is

    function cmd_write (
        addr: in unsigned(23 downto 0);
        data: in std_logic_vector(31 downto 0)
    ) return t_byte_array is
        variable v_byte_array : t_byte_array(0 to 7);
    begin
        v_byte_array(0) := C_OP_WRITE;
        v_byte_array(1) := x"00";
        v_byte_array(2) := std_logic_vector(addr(15 downto 8));
        v_byte_array(3) := std_logic_vector(addr(7 downto 0));
        v_byte_array(4) := data(31 downto 24);
        v_byte_array(5) := data(23 downto 16);
        v_byte_array(6) := data(15 downto 8);
        v_byte_array(7) := data(7 downto 0);
        return v_byte_array;
    end cmd_write;
    
    function cmd_read (
        addr: in unsigned(23 downto 0)
    ) return t_byte_array is
        variable v_byte_array : t_byte_array(0 to 7);
    begin
        v_byte_array(0) := C_OP_READ;
        v_byte_array(1) := x"00";
        v_byte_array(2) := std_logic_vector(addr(15 downto 8));
        v_byte_array(3) := std_logic_vector(addr(7 downto 0));
        v_byte_array(4) := (others => '-');
        v_byte_array(5) := (others => '-');
        v_byte_array(6) := (others => '-');
        v_byte_array(7) := (others => '-');
        return v_byte_array;
    end cmd_read;
    
    function cmd_read_response (
        data: in std_logic_vector(31 downto 0)
    ) return t_byte_array is
        variable v_byte_array : t_byte_array(0 to 7);
    begin
        v_byte_array(0) := C_OP_READ_RESP;
        v_byte_array(1) := (others => '-');
        v_byte_array(2) := (others => '-');
        v_byte_array(3) := (others => '-');
        v_byte_array(4) := data(31 downto 24);
        v_byte_array(5) := data(23 downto 16);
        v_byte_array(6) := data(15 downto 8);
        v_byte_array(7) := data(7 downto 0);
        return v_byte_array;
    end cmd_read_response;
    
end package body drm_reg_bridge_vvc_pkg;

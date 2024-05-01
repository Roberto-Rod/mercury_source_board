----------------------------------------------------------------------------------
--! @file mercury_source_board_version.vhd
--! @brief Source board version package file
--!
--! Contains descriptions of Mercury Source Board FPGA version and drawing number.
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

--! @brief Package containing version information and drawing number.
--!
--! Drawing Number = SW0008

package version_pkg is

constant VERS_MAJ : natural := 2;  --! FPGA Version, Major
constant VERS_MIN : natural := 0;  --! FPGA Version, Minor
constant VERS_BLD : natural := 4;  --! FPGA Version, Build

constant FPGA_VERSION_MAJOR : std_logic_vector(7 downto 0)  := std_logic_vector(to_unsigned(VERS_MAJ, 8)); 
constant FPGA_VERSION_MINOR : std_logic_vector(7 downto 0)  := std_logic_vector(to_unsigned(VERS_MIN, 8)); 
constant FPGA_VERSION_BUILD : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(VERS_BLD, 16));

constant FPGA_DWG_NUMBER    : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(8, 16));  --! FPGA Drawing Number

end version_pkg;

package body version_pkg is 
end version_pkg;


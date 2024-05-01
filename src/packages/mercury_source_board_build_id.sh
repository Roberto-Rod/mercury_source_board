#! /bin/bash

# Get the latest commit SHA from Git
id=$(git rev-parse HEAD | head -c 16)

# Output a VHDL package file with the build ID as a constant
cat << EOF > mercury_source_board_build_id.vhd
----------------------------------------------------------------------------------
--! @file mercury_source_board_build_id.vhd
--! @brief Source board build ID package file - auto-generated
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--! @brief Package containing build ID

package build_id_pkg is

constant FPGA_BUILD_ID : std_logic_vector(63 downto 0) := x"$id";

end build_id_pkg;

package body build_id_pkg is 
end build_id_pkg;
EOF
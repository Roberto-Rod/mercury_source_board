# Active-HDL Compilation Script
set lib_name "general_registers"

# Create/clear the library
vlib $lib_name
vdel -lib $lib_name -all

set srcdirectives "-work $lib_name -nowarn COMP96_0564 -nowarn DAGGEN_0523"
set tbdirectives "-work $lib_name -2008 -nowarn COMP96_0564 -nowarn DAGGEN_0523"
set src_path "../../src"
set tb_path "../../tb"

# Compile the sources
eval vcom  $srcdirectives $src_path/../submodules/vhdl_general/reg_ctrl/reg_pkg.vhd
eval vcom  $srcdirectives $src_path/packages/mercury_pkg.vhd
eval vcom  $srcdirectives $src_path/packages/mercury_source_board_version.vhd
eval vcom  $srcdirectives $src_path/packages/mercury_source_board_build_id.vhd
eval vcom  $srcdirectives $src_path/general_registers/general_registers.vhd

# Compile the TB
eval vcom  $tbdirectives $tb_path/general_registers/general_registers_vvc_th.vhd
eval vcom  $tbdirectives $tb_path/general_registers/general_registers_vvc_tb.vhd
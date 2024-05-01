# Active-HDL Compilation Script
set curdir [pwd]

# Compile the UVVM packages/VIPs
cd ../../submodules/_sim_libs/uvvm/

do compile.tcl

# Change directory back to where we started
cd $curdir
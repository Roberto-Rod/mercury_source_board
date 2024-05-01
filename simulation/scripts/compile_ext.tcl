# Active-HDL Compilation Script
# Compiles the testbench dependencies in external libraries

# Store the current working directory
set WDIR [pwd]

# Compile the Bitvis packages
cd ../../submodules/_sim_libs/bitvis
do compile.tcl

# Compile the testbench support package
cd ../tb_support/_active-hdl
do compile.tcl

# Change the directory back to the original working directory
cd $WDIR

# Set the working library back to default
set worklib work

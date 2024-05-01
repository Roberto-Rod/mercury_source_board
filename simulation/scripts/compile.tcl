# Active-HDL Compilation Script
vlib work
set worklib work

# Clear work library
vdel -lib work -all

do compile_ext.tcl
do compile_ip.tcl
do compile_sub.tcl
do compile_src.tcl
do compile_tb.tcl

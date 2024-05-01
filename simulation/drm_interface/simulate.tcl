asim -stack 64 -O5 +access +r drm_interface.drm_reg_bridge_vvc_tb

do wave.do

run -all

#WaveRestoreCursors {Cursor 1} {1411622 ps} {0}
#WaveRestoreZoom {0 ps} {380 us}
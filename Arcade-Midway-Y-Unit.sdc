derive_pll_clocks
derive_clock_uncertainty

# core specific constraints

# TMS34010 (rtl/tms34010): its logic runs on every other clk_sys cycle
# (cpu_ce in rtl/midway_yunit.sv) and every register inside it changes only on
# an enabled edge, so paths from one of its registers to another have two
# clocks. Paths into it from the rest of the board keep the normal check.
set_multicycle_path -setup -end 2 -from [get_registers {*|tms34010:cpu|*}] -to [get_registers {*|tms34010:cpu|*}]
set_multicycle_path -hold  -end 1 -from [get_registers {*|tms34010:cpu|*}] -to [get_registers {*|tms34010:cpu|*}]

# Sound CPU (6809E in rtl/sound/williams_sound.sv): its registers change only
# on E/Q edges at least 32 clocks apart, nothing on the sound board samples
# its address/data outputs earlier than A_SETTLE (8) clocks after an E edge,
# and its read data (din_r) is held for D_SETTLE (8) clocks before the E edge
# that takes it.
set_multicycle_path -setup -end 8 -from [get_registers {*|williams_sound:*|mc6809is:cpu|*}] -to [get_keepers {*|williams_sound:*|*}]
set_multicycle_path -hold  -end 7 -from [get_registers {*|williams_sound:*|mc6809is:cpu|*}] -to [get_keepers {*|williams_sound:*|*}]
set_multicycle_path -setup -end 8 -from [get_registers {*|williams_sound:*|din_r[*]}] -to [get_registers {*|williams_sound:*|mc6809is:cpu|*}]
set_multicycle_path -hold  -end 7 -from [get_registers {*|williams_sound:*|din_r[*]}] -to [get_registers {*|williams_sound:*|mc6809is:cpu|*}]

# YM2151 (jt51) phase generator: the keycode stage is clock-enabled at
# 3.58 MHz and its inputs come from the clock-enabled register file, so the
# detune/modulation adder chain in front of it has more than one clock.
set_multicycle_path -setup -end 2 -to [get_registers {*|jt51_pg:u_pg|keycode_II[*]}]
set_multicycle_path -hold  -end 1 -to [get_registers {*|jt51_pg:u_pg|keycode_II[*]}]

# HQ2x scandoubler filter (sys/hq2x.sv, used when Scandoubler Fx is HQ2x):
# every register of its Blend stage changes only while the scandoubler's
# ce_x4i is high. ce_x4i comes at a quarter of the pixel length (12 clocks at
# 96 MHz / 8 MHz, so every 3 clocks) and once more at each HSync edge, which
# is in the blanking. Paths from one Blend register to another therefore have
# more than one clock.
set_multicycle_path -setup -end 2 -from [get_registers {*|Hq2x:Hq2x|Blend:blender|*}] -to [get_registers {*|Hq2x:Hq2x|Blend:blender|*}]
set_multicycle_path -hold  -end 1 -from [get_registers {*|Hq2x:Hq2x|Blend:blender|*}] -to [get_registers {*|Hq2x:Hq2x|Blend:blender|*}]

# wind_tunnel.sdc - timing constraints
# Tells the Timing Analyzer that CLOCK_50 is 50 MHz (20 ns period).
# Without this, Quartus reports the design as unconstrained.
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_clock_uncertainty

# Switches, keys, the fan tach and the fan PWM are slow/asynchronous signals
# (synchronized inside the design), so don't time them.
set_false_path -from [get_ports {SW[*] KEY[*] FAN_TACH}]
set_false_path -to   [get_ports {LEDR[*] HEX*[*] FAN_PWM}]

# VGA: all outputs are registered and change once per 40 ns pixel; VGA_CLK
# rises mid-pixel (see vga_timing.v), leaving ~20 ns of margin each side.
set_false_path -to   [get_ports {VGA_R[*] VGA_G[*] VGA_B[*] VGA_CLK VGA_HS VGA_VS VGA_BLANK_N VGA_SYNC_N}]

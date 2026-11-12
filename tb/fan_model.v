// ============================================================================
// fan_model.v - behavioral model of the Noctua NF-P12 redux-1700 PWM
// SIMULATION ONLY (uses 'real' and # delays - not synthesizable)
//
// - Measures the duty cycle of 'pwm' over each 2000-clock window
// - Target speed (Noctua white paper: roughly linear 20%..100%):
//     duty >= 20% : 550 + (duty - 20%) * (1700 - 550) / 80%
//     duty <  20% : 550 * duty / 20%   (Noctua fans stop at 0%)
// - First-order lag toward the target with time constant TAU_S
//   (real fan: roughly 0.5-1 s; use something small to keep sims short)
// - Tach: 2 pulses per revolution -> toggles 4 times per revolution
// - Optional asymmetry between the two pulses (real magnets aren't perfect)
//
// Reused later for PID / step-test / auto-tune simulations.
// ============================================================================
`timescale 1ns/1ps
module fan_model #(
	parameter real TAU_S      = 0.5,     // speed time constant (seconds)
	parameter real ASYMMETRY  = 0.03,    // +/- fraction between the 2 pulses
	parameter real CLK_PERIOD = 20.0     // ns
)(
	input      clk,
	input      pwm,          // 1 = high (after any external inversion)
	output reg tach
);

real duty_frac;
real target_rpm;
real rpm;
integer high_cnt;
integer win_cnt;

initial begin
	tach       = 1'b1;
	rpm        = 0.0;
	target_rpm = 0.0;
	duty_frac  = 0.0;
	high_cnt   = 0;
	win_cnt    = 0;
end

/* duty measurement + first-order speed update every 2000 clocks (80 us) */
always @(posedge clk)
begin
	if (pwm) high_cnt = high_cnt + 1;
	win_cnt = win_cnt + 1;
	if (win_cnt == 2000)
	begin
		duty_frac = high_cnt / 2000.0;
		if (duty_frac >= 0.2)
			target_rpm = 550.0 + (duty_frac - 0.2) * (1700.0 - 550.0) / 0.8;
		else
			target_rpm = 550.0 * duty_frac / 0.2;
		// rpm += (target - rpm) * dt / tau
		rpm = rpm + (target_rpm - rpm) * (2000.0 * CLK_PERIOD * 1.0e-9) / TAU_S;
		high_cnt = 0;
		win_cnt  = 0;
	end
end

/* tach generator: each half revolution = one full tach pulse (high + low) */
real half_rev_ns;
integer pole;
initial begin
	pole = 0;
	forever begin
		if (rpm < 50.0)
			#1_000_000;                      // effectively stopped: no edges
		else
		begin
			half_rev_ns = 30.0e9 / rpm;      // 60 s / rpm / 2 pulses
			if (pole == 0) half_rev_ns = half_rev_ns * (1.0 + ASYMMETRY);
			else           half_rev_ns = half_rev_ns * (1.0 - ASYMMETRY);
			pole = 1 - pole;
			tach = 1'b0;
			#(half_rev_ns / 2.0);
			tach = 1'b1;
			#(half_rev_ns / 2.0);
		end
	end
end

endmodule

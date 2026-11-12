`timescale 1ns/1ps
// ============================================================================
// pid_controller.v - fixed-point PID datapath + control FSM   [SKELETON - M3]
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
//
// Lab 9 style: registers + ONE shared multiplier + an FSM that sequences
// the math, one operation per state. Runs once per 'tick' (100 Hz), so
// there are 500,000 clocks available per update - no timing pressure.
//
// Number formats (must match python/pid_model.py bit-for-bit):
//   setpoint, measured : unsigned 16-bit RPM
//   e = setpoint - measured           : signed 17-bit
//   kp, ki, kd                         : unsigned Q8.8 (256 = 1.0)
//   integ  (sum of e)                  : signed 32-bit, clamped to +/-INTEG_MAX
//   u = (kp*e + ki*integ + kd*(e - e_prev)) >>> 8   : signed, in PWM counts
//   duty = DUTY_BIAS + u, clamped to [DUTY_MIN, DUTY_MAX]
//   Plant gain for the Noctua: ~1600 counts / 1150 RPM = ~1.4 counts per RPM
//
// Anti-windup (conditional integration): skip integ += e when the output is
// already saturated AND e would push it further into saturation.
//
// FSM (one state per step):
//   IDLE -> ERR (e, de) -> MUL_P -> MUL_I -> MUL_D -> SUM -> CLAMP -> DONE
//
// TODO (M3):
//   1. Declare 'reg signed' for EVERY signed value. One unsigned operand
//      turns the whole expression unsigned (negative error -> huge positive).
//   2. Sign-extend explicitly: {{15{e[16]}}, e} or $signed().
//   3. Multiply in its own state; register the 48-bit product.
//   4. Testbench: feed the vectors from python/pid_model.py and compare.
// ============================================================================
module pid_controller #(
	parameter [10:0] DUTY_MIN  = 11'd400,     // 20% - Noctua's specified minimum
	parameter [10:0] DUTY_MAX  = 11'd2000,    // 100%
	parameter [10:0] DUTY_BIAS = 11'd1000,    // starting point (50%)
	parameter [31:0] INTEG_MAX = 32'd200000
)(
	input             clk,
	input             rst,         // active-low
	input             enable,      // 0 = hold integrator at 0 (manual mode)
	input             tick,        // 1-clk pulse at the control rate (100 Hz)
	input      [15:0] setpoint,    // RPM
	input      [15:0] measured,    // RPM
	input      [15:0] kp,          // Q8.8
	input      [15:0] ki,          // Q8.8
	input      [15:0] kd,          // Q8.8
	output reg [10:0] duty,        // to pwm_gen
	output reg        done         // 1-clk pulse when duty updates
);

reg [2:0] S;
parameter IDLE  = 3'd0,
          ERR   = 3'd1,
          MUL_P = 3'd2,
          MUL_I = 3'd3,
          MUL_D = 3'd4,
          SUM   = 3'd5,
          CLAMP = 3'd6,
          DONE  = 3'd7;

// TODO: datapath registers (all 'reg signed'): e, e_prev, de, integ, acc, product

// Placeholder: hold the bias duty so the project compiles and the fan runs.
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		S    <= IDLE;
		duty <= DUTY_BIAS;
		done <= 1'b0;
	end
	else
	begin
		done <= 1'b0;
		// TODO: replace with the FSM described above
		if (tick == 1'b1)
			done <= 1'b1;
	end
end

endmodule

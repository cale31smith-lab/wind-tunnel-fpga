`timescale 1ns/1ps
// ============================================================================
// autotune.v - relay (Astrom-Hagglund) PID auto-tuner     [SKELETON - M5]
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
//
// Idea: replace the PID with a simple relay around the setpoint:
//   if RPM < setpoint: duty = DUTY_HI  else: duty = DUTY_LO
// The fan then oscillates around the setpoint by itself. Measure:
//   Tu = oscillation period (ticks between upward setpoint crossings)
//   a  = oscillation amplitude in RPM ((max - min) / 2)
//   d  = relay amplitude in PWM counts ((DUTY_HI - DUTY_LO) / 2)
// Ultimate gain: Ku = 4*d / (pi*a)   (use 4/pi ~= 1.273 ~= 326/256 in Q8.8)
// Ziegler-Nichols PID: Kp = 0.6*Ku, Ki = 1.2*Ku/Tu, Kd = 0.075*Ku*Tu
// (Ki, Kd scaled for the 100 Hz tick; outputs in Q8.8 for pid_controller)
//
// FSM:
//   IDLE -> RELAY (wait 2 cycles to settle) -> MEASURE (average 3 cycles)
//        -> CALC_KU -> CALC_GAINS (seq_divider + shared multiplier) -> DONE
//
// TODO (M5): implement. Validate the math in python/pid_model.py first.
// ============================================================================
module autotune #(
	parameter [10:0] DUTY_HI = 11'd1400,
	parameter [10:0] DUTY_LO = 11'd800
)(
	input             clk,
	input             rst,         // active-low
	input             start,
	input             tick,        // 100 Hz
	input      [15:0] setpoint,    // RPM to oscillate around
	input      [15:0] measured,    // RPM
	output reg [10:0] duty,        // relay output while tuning
	output reg [15:0] kp,          // Q8.8 results
	output reg [15:0] ki,
	output reg [15:0] kd,
	output reg        done
);

reg [2:0] S;
parameter IDLE       = 3'd0,
          RELAY      = 3'd1,
          MEASURE    = 3'd2,
          CALC_KU    = 3'd3,
          CALC_GAINS = 3'd4,
          FINISH     = 3'd5;

// TODO: implement. Placeholder: safe default gains (Kp = 0.5).
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		S    <= IDLE;
		duty <= DUTY_LO;
		kp   <= 16'd128;    // 0.5 in Q8.8
		ki   <= 16'd4;      // ~0.016
		kd   <= 16'd0;
		done <= 1'b0;
	end
	else
	begin
		done <= start;     // placeholder
	end
end

endmodule

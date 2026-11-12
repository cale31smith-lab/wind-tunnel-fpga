`timescale 1ns/1ps
// ============================================================================
// mode_fsm.v - selects what drives the fan                 [SKELETON - M3]
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
//
// KEY[1] (active-low) press cycles the mode:
//   MANUAL -> CLOSED_LOOP -> STEP_TEST -> AUTOTUNE -> MANUAL ...
//   MANUAL      : duty from switches (M1 behavior)
//   CLOSED_LOOP : PID holds the RPM setpoint from the switches
//   STEP_TEST   : step_test.v runs a step and measures performance
//   AUTOTUNE    : autotune.v finds kp/ki/kd, then returns to CLOSED_LOOP
//
// TODO (M3):
//   1. Synchronize KEY[1] (2 FFs), then detect the press as a falling edge
//      of the synchronized signal (one press = one mode step)
//   2. Debounce: ignore new presses for ~20 ms after one is accepted
//   3. Show the mode on LEDR or HEX5 (e.g. "1".."4")
//   4. Return from STEP_TEST / AUTOTUNE when their 'done' goes high
// ============================================================================
module mode_fsm (
	input            clk,
	input            rst,           // active-low
	input            key_mode_n,    // KEY[1], active-low, asynchronous
	input            step_done,     // from step_test
	input            tune_done,     // from autotune
	output reg [1:0] mode
);

parameter MANUAL      = 2'd0,
          CLOSED_LOOP = 2'd1,
          STEP_TEST   = 2'd2,
          AUTOTUNE    = 2'd3;

// TODO: synchronizer, debounce, next-state logic
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
		mode <= MANUAL;
	else
		mode <= mode;     // placeholder: stays in MANUAL
end

endmodule

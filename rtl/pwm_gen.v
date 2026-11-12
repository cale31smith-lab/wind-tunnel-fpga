`timescale 1ns/1ps
// ============================================================================
// pwm_gen.v - 25 kHz PWM generator for a 4-pin PC fan
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
// Team: James Wood, Cale Smith
//
// How it works:
//   A counter runs 0 .. PERIOD-1 forever (50 MHz / 2000 = 25 kHz).
//   pwm = 1 while (count < duty_reg), else 0.
//   duty = 0    -> 0%   (always low)
//   duty = 1000 -> 50%
//   duty = 2000 -> 100% (always high)
//
// duty is only loaded at the START of each period (duty_reg), so changing
// duty mid-period never produces a short "glitch" pulse.
// The output is registered, so the pin never sees combinational glitches.
// ============================================================================
module pwm_gen #(
	parameter PERIOD = 2000            // clk cycles per PWM period (50 MHz / 25 kHz)
)(
	input             clk,
	input             rst,             // active-low (KEY0)
	input      [10:0] duty,            // 0 .. PERIOD (values above PERIOD = 100%)
	output reg        pwm,             // 1 = fan "on" portion of the period
	output            period_start     // 1-clk pulse at the start of each period
);

reg [10:0] count;
reg [10:0] duty_reg;

assign period_start = (count == 11'd0);

/* period counter */
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
		count <= 11'd0;
	else if (count == PERIOD - 1)
		count <= 11'd0;
	else
		count <= count + 11'd1;
end

/* latch duty once per period (glitch-free duty changes) */
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
		duty_reg <= 11'd0;
	else if (count == PERIOD - 1)
		duty_reg <= duty;
end

/* registered comparator output */
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
		pwm <= 1'b0;
	else
		pwm <= (count < duty_reg);
end

endmodule

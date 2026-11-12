`timescale 1ns/1ps
// ============================================================================
// step_test.v - hardware step-response measurement        [SKELETON - M4]
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
//
// The board tests itself: settle at RPM_LOW, step the setpoint to RPM_HIGH,
// then measure (all in 10 ms ticks):
//   rise time      : ticks from 10% to 90% of the step
//   overshoot      : (peak - RPM_HIGH) * 100 / (RPM_HIGH - RPM_LOW)  [%]
//   settling time  : ticks until RPM stays within +/-5% for good
//   steady error   : |RPM_HIGH - average of last N samples|
//
// FSM:
//   IDLE -> SETTLE_LOW (hold setpoint low for 3 s)
//        -> STEP (setpoint = high, start timer)
//        -> WATCH (track 10%/90% crossings, peak, last time outside band)
//        -> COMPUTE (overshoot % with seq_divider)
//        -> SHOW (results on HEX; KEY cycles through metrics) -> done
//
// TODO (M4): implement the FSM above; reuse seq_divider for the % math.
// ============================================================================
module step_test #(
	parameter [15:0] RPM_LOW  = 16'd800,
	parameter [15:0] RPM_HIGH = 16'd1400
)(
	input             clk,
	input             rst,           // active-low
	input             start,         // 1-clk pulse from mode_fsm
	input             tick,          // 100 Hz
	input      [15:0] measured,      // RPM
	output reg [15:0] setpoint,      // drives the PID during the test
	output reg [15:0] rise_ticks,
	output reg [15:0] settle_ticks,
	output reg [7:0]  overshoot_pct,
	output reg [15:0] steady_err,
	output reg        done
);

reg [2:0] S;
parameter IDLE       = 3'd0,
          SETTLE_LOW = 3'd1,
          STEP       = 3'd2,
          WATCH      = 3'd3,
          COMPUTE    = 3'd4,
          SHOW       = 3'd5;

// TODO: implement. Placeholder outputs so the project compiles.
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		S             <= IDLE;
		setpoint      <= RPM_LOW;
		rise_ticks    <= 16'd0;
		settle_ticks  <= 16'd0;
		overshoot_pct <= 8'd0;
		steady_err    <= 16'd0;
		done          <= 1'b0;
	end
	else
	begin
		done <= start;     // placeholder: finishes immediately
	end
end

endmodule

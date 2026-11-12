`timescale 1ns/1ps
// ============================================================================
// two_decimal_vals.v - unsigned 0..99 -> two 7-segment digits
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
//
// Used for the PWM duty percentage on HEX5:HEX4. Values above 99 show 99.
// ============================================================================
module two_decimal_vals (
	input  [6:0] val,
	output [6:0] seg7_dig0,    // ones
	output [6:0] seg7_dig1     // tens
);

reg [6:0] v;
reg [3:0] d0, d1;

always @(*)
begin
	if (val > 7'd99)
		v = 7'd99;
	else
		v = val;
	d1 = v / 7'd10;
	d0 = v % 7'd10;
end

seven_segment ones_disp (d0, seg7_dig0);
seven_segment tens_disp (d1, seg7_dig1);

endmodule

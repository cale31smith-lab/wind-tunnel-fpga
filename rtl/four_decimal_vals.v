`timescale 1ns/1ps
// ============================================================================
// four_decimal_vals.v - unsigned 0..9999 -> four 7-segment digits
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
//
// Extends the class's three_decimal_vals_w_neg (Lab 8) to 4 digits for RPM.
// No sign needed: speed is never negative. Values above 9999 show 9999.
// Leading zeros are blanked (e.g. 850 shows as " 850") so it reads cleanly.
// Division/modulo by constants synthesize to fixed combinational logic.
// ============================================================================
module four_decimal_vals (
	input  [15:0] val,
	output [6:0]  seg7_dig0,    // ones      (HEX0)
	output [6:0]  seg7_dig1,    // tens      (HEX1)
	output [6:0]  seg7_dig2,    // hundreds  (HEX2)
	output [6:0]  seg7_dig3     // thousands (HEX3)
);

reg [13:0] v;
reg [3:0]  d0, d1, d2, d3;

always @(*)
begin
	if (val > 16'd9999)
		v = 14'd9999;
	else
		v = val[13:0];

	d3 = v / 14'd1000;
	d2 = (v % 14'd1000) / 14'd100;
	d1 = (v % 14'd100) / 14'd10;
	d0 = v % 14'd10;
end

wire [6:0] raw3, raw2, raw1;

seven_segment ones_disp (d0, seg7_dig0);
seven_segment tens_disp (d1, raw1);
seven_segment huns_disp (d2, raw2);
seven_segment thou_disp (d3, raw3);

/* leading-zero blanking (7'b1111111 = all segments off) */
assign seg7_dig3 = (v < 14'd1000) ? 7'b1111111 : raw3;
assign seg7_dig2 = (v < 14'd100)  ? 7'b1111111 : raw2;
assign seg7_dig1 = (v < 14'd10)   ? 7'b1111111 : raw1;

endmodule

`timescale 1ns/1ps
// ============================================================================
// seven_segment.v - hex digit -> 7-segment pattern (reused from Labs 3/8/11)
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
//
// HEX out - DE1-SoC
//  ---0---
// |       |
// 5       1
// |       |
//  ---6---
// |       |
// 4       2
// |       |
//  ---3---
// o = {g,f,e,d,c,b,a} = {o[6]..o[0]}, ACTIVE LOW (0 = segment ON)
// ============================================================================
module seven_segment(
	input wire [3:0] i,
	output reg [6:0] o
);

always @(*)
begin
	case (i)
		4'h0: o = 7'b1000000;
		4'h1: o = 7'b1111001;
		4'h2: o = 7'b0100100;
		4'h3: o = 7'b0110000;
		4'h4: o = 7'b0011001;
		4'h5: o = 7'b0010010;
		4'h6: o = 7'b0000010;
		4'h7: o = 7'b1111000;
		4'h8: o = 7'b0000000;
		4'h9: o = 7'b0010000;
		4'hA: o = 7'b0001000;
		4'hB: o = 7'b0000011;
		4'hC: o = 7'b1000110;
		4'hD: o = 7'b0100001;
		4'hE: o = 7'b0000110;
		4'hF: o = 7'b0001110;
		default: o = 7'b1111111;
	endcase
end

endmodule

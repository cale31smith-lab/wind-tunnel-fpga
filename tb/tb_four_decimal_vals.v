// ============================================================================
// tb_four_decimal_vals.v - self-checking test of the 4-digit RPM display
// Decodes the 7-segment patterns back to digits and checks leading-zero
// blanking and the 9999 clamp.
// ============================================================================
`timescale 1ns/1ps
module tb_four_decimal_vals;

reg  [15:0] val;
wire [6:0]  d0, d1, d2, d3;

four_decimal_vals dut (.val(val), .seg7_dig0(d0), .seg7_dig1(d1), .seg7_dig2(d2), .seg7_dig3(d3));

// 7-segment pattern -> character (' ' = blank, '?' = bad pattern)
function [7:0] seg2chr(input [6:0] s);
	case (s)
		7'b1000000: seg2chr = "0";  7'b1111001: seg2chr = "1";
		7'b0100100: seg2chr = "2";  7'b0110000: seg2chr = "3";
		7'b0011001: seg2chr = "4";  7'b0010010: seg2chr = "5";
		7'b0000010: seg2chr = "6";  7'b1111000: seg2chr = "7";
		7'b0000000: seg2chr = "8";  7'b0010000: seg2chr = "9";
		7'b1111111: seg2chr = " ";
		default:    seg2chr = "?";
	endcase
endfunction

integer errors = 0;
reg [31:0] shown;

task check(input [15:0] v, input [31:0] expect_str);
	begin
		val = v; #10;
		shown = {seg2chr(d3), seg2chr(d2), seg2chr(d1), seg2chr(d0)};
		if (shown !== expect_str) begin
			$display("FAIL %0d shows \"%s\" (expected \"%s\")", v, shown, expect_str);
			errors = errors + 1;
		end
		else
			$display("ok   %5d shows \"%s\"", v, shown);
	end
endtask

initial begin
	check(16'd0,     "   0");
	check(16'd7,     "   7");
	check(16'd42,    "  42");
	check(16'd550,   " 550");
	check(16'd1000,  "1000");
	check(16'd1700,  "1700");
	check(16'd9999,  "9999");
	check(16'd12345, "9999");   // clamp
	if (errors == 0) $display("PASS tb_four_decimal_vals");
	else             $display("FAIL tb_four_decimal_vals (%0d errors)", errors);
	$finish;
end

endmodule

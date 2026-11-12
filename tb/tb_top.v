// ============================================================================
// tb_top.v - M1 integration test: board top level + simulated Noctua fan
// Sets SW to a duty %, lets the fan model spin up, and checks that the
// measured RPM matches the fan model's true speed and that HEX5:HEX4 show
// the duty. The fan model uses a short time constant so this runs quickly.
// ============================================================================
`timescale 1ns/1ps
module tb_top;

reg        CLOCK_50 = 1'b0;
reg  [3:0] KEY = 4'b1110;     // KEY0 pressed = reset
reg  [9:0] SW  = 10'd0;
wire [9:0] LEDR;
wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
wire       FAN_PWM, FAN_TACH;
wire [7:0] VGA_R, VGA_G, VGA_B;
wire       VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N;

always #10 CLOCK_50 = ~CLOCK_50;

wind_tunnel_top #(.PWM_INVERT(1'b0), .DISPLAY_TICKS(500000)) dut (
	.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW), .LEDR(LEDR),
	.HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5),
	.FAN_PWM(FAN_PWM), .FAN_TACH(FAN_TACH),
	.VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_CLK(VGA_CLK),
	.VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_BLANK_N(VGA_BLANK_N), .VGA_SYNC_N(VGA_SYNC_N)
);

fan_model #(.TAU_S(0.02), .ASYMMETRY(0.03)) fan (
	.clk(CLOCK_50), .pwm(FAN_PWM), .tach(FAN_TACH)
);

integer errors = 0;
real    err_pct;

task run_point(input [6:0] pct, input [6:0] seg_tens, input [6:0] seg_ones);
	begin
		SW = {3'b000, pct};
		#300_000_000;                                   // 0.3 s = 15 tau
		repeat (2) @(posedge dut.rpm_valid);
		@(posedge CLOCK_50);
		err_pct = 100.0 * (dut.rpm - fan.rpm) / fan.rpm;
		if (err_pct > 2.0 || err_pct < -2.0) begin
			$display("FAIL %0d%%: fan model %0.0f RPM, FPGA measured %0d", pct, fan.rpm, dut.rpm);
			errors = errors + 1;
		end
		else
			$display("ok   %0d%% duty: fan model %4.0f RPM, FPGA measured %0d (%0.2f%%)",
			         pct, fan.rpm, dut.rpm, err_pct);
		if (HEX5 !== seg_tens || HEX4 !== seg_ones) begin
			$display("FAIL %0d%%: HEX5:HEX4 = %b %b", pct, HEX5, HEX4);
			errors = errors + 1;
		end
	end
endtask

initial begin
	#100 KEY = 4'b1111;                                 // release reset
	run_point(7'd50, 7'b0010010, 7'b1000000);           // "50"
	run_point(7'd90, 7'b0010000, 7'b1000000);           // "90"
	run_point(7'd25, 7'b0100100, 7'b0010010);           // "25"
	if (LEDR[1] !== 1'b0) begin
		$display("FAIL stalled LED is on while fan spins");
		errors = errors + 1;
	end
	if (errors == 0) $display("PASS tb_top");
	else             $display("FAIL tb_top (%0d errors)", errors);
	$finish;
end

endmodule

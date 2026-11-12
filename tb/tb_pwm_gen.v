// ============================================================================
// tb_pwm_gen.v - self-checking testbench for pwm_gen
// Checks: period = 2000 clocks (25 kHz) and high time = duty for several
// duty values, including 0%, 100%, and an out-of-range value (clamps to 100%).
// ============================================================================
`timescale 1ns/1ps
module tb_pwm_gen;

reg         clk = 1'b0;
reg         rst = 1'b0;
reg  [10:0] duty = 11'd0;
wire        pwm;
wire        period_start;

always #10 clk = ~clk;   // 50 MHz

pwm_gen #(.PERIOD(2000)) dut (
	.clk(clk), .rst(rst), .duty(duty), .pwm(pwm), .period_start(period_start)
);

integer errors = 0;
integer highs, cycles, i;

// count high cycles over exactly one period, starting at a period boundary
task measure_period;
	begin
		@(posedge clk); while (period_start !== 1'b1) @(posedge clk);
		highs  = 0;
		cycles = 0;
		@(posedge clk);
		while (period_start !== 1'b1)
		begin
			if (pwm === 1'b1) highs = highs + 1;
			cycles = cycles + 1;
			@(posedge clk);
		end
		if (pwm === 1'b1) highs = highs + 1;   // the cycle where period_start=1
		cycles = cycles + 1;
	end
endtask

task check_duty(input [10:0] d, input integer expect_highs);
	begin
		duty = d;
		measure_period;               // let the new duty latch
		measure_period;               // measure a clean period
		if (cycles !== 2000) begin
			$display("FAIL duty=%0d: period %0d clocks (expected 2000)", d, cycles);
			errors = errors + 1;
		end
		if (highs !== expect_highs) begin
			$display("FAIL duty=%0d: high for %0d clocks (expected %0d)", d, highs, expect_highs);
			errors = errors + 1;
		end
		else
			$display("ok   duty=%4d -> high %4d / %0d clocks (%0d%%)", d, highs, cycles, highs/20);
	end
endtask

initial begin
	#55 rst = 1'b1;
	check_duty(11'd0,    0);
	check_duty(11'd1,    1);
	check_duty(11'd400,  400);    // 20% (Noctua minimum)
	check_duty(11'd1000, 1000);   // 50%
	check_duty(11'd1999, 1999);
	check_duty(11'd2000, 2000);   // 100%
	check_duty(11'd2047, 2000);   // above range -> 100%
	check_duty(11'd700,  700);

	if (errors == 0) $display("PASS tb_pwm_gen");
	else             $display("FAIL tb_pwm_gen (%0d errors)", errors);
	$finish;
end

endmodule

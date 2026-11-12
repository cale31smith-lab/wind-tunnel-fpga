// ============================================================================
// tb_seq_divider.v - self-checking testbench for seq_divider
// Compares against Verilog's '/' and '%' for edge cases + 500 random pairs,
// including the real RPM case (3,000,000,000 / revolution period).
// ============================================================================
`timescale 1ns/1ps
module tb_seq_divider;

reg         clk = 1'b0;
reg         rst = 1'b0;
reg         start = 1'b0;
reg  [31:0] dividend, divisor;
wire [31:0] quotient, remainder;
wire        busy, done;

always #10 clk = ~clk;

seq_divider #(.WIDTH(32)) dut (
	.clk(clk), .rst(rst), .start(start), .dividend(dividend), .divisor(divisor),
	.quotient(quotient), .remainder(remainder), .busy(busy), .done(done)
);

integer errors = 0;
integer i, latency;

task run_div(input [31:0] a, input [31:0] b);
	begin
		@(negedge clk);
		dividend = a; divisor = b; start = 1'b1;
		@(negedge clk);
		start = 1'b0;
		latency = 1;
		while (done !== 1'b1) begin @(negedge clk); latency = latency + 1; end
		if (quotient !== a / b || remainder !== a % b) begin
			$display("FAIL %0d / %0d -> q=%0d r=%0d (expected q=%0d r=%0d)",
			         a, b, quotient, remainder, a / b, a % b);
			errors = errors + 1;
		end
	end
endtask

initial begin
	#55 rst = 1'b1;

	run_div(32'd3000000000, 32'd1764706);   // 1700 RPM
	$display("3e9 / 1764706 = %0d RPM (expect 1699), latency %0d clocks", quotient, latency);
	run_div(32'd3000000000, 32'd5454545);   // ~550 RPM
	$display("3e9 / 5454545 = %0d RPM (expect 550)", quotient);
	run_div(32'd0,          32'd7);
	run_div(32'd7,          32'd7);
	run_div(32'd6,          32'd7);
	run_div(32'hFFFFFFFF,   32'd1);
	run_div(32'hFFFFFFFF,   32'hFFFFFFFF);
	run_div(32'h80000000,   32'd3);

	for (i = 0; i < 500; i = i + 1)
		run_div($random, ($random & 32'h00FFFFFF) | 32'd1);   // nonzero divisor

	if (errors == 0) $display("PASS tb_seq_divider (508 divisions)");
	else             $display("FAIL tb_seq_divider (%0d errors)", errors);
	$finish;
end

endmodule

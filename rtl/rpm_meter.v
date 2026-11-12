`timescale 1ns/1ps
// ============================================================================
// rpm_meter.v - fan tach pin in, RPM number out
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
//
//   tach pin -> tach_period (clk cycles per revolution)
//            -> seq_divider (RPM = 60 * f_clk / rev_period)
//            -> rpm register (holds last good value; 0 when stalled)
//
// With a 50 MHz clock: RPM = 3_000_000_000 / rev_period
//   1700 RPM -> rev_period = 1,764,706 cycles (35.3 ms per revolution)
//    550 RPM -> rev_period = 5,454,545 cycles
// Because we time a full revolution, a new RPM value arrives once per
// revolution (~30-110 ms) - plenty fast for a 10 Hz to 100 Hz control loop.
// ============================================================================
module rpm_meter #(
	parameter [31:0] RPM_NUMERATOR   = 32'd3000000000, // 60 * 50,000,000
	parameter        GLITCH_CYCLES   = 2500,
	parameter        MIN_HALF_CYCLES = 300000,
	parameter        TIMEOUT_CYCLES  = 25000000
)(
	input             clk,
	input             rst,        // active-low
	input             tach_in,    // raw fan tach pin
	output reg [15:0] rpm,        // measured speed (0 .. 65535)
	output reg        rpm_valid,  // 1-clk pulse each time rpm updates
	output            stalled,
	output            tach_clean
);

wire [31:0] rev_period;
wire        period_valid;

tach_period #(
	.GLITCH_CYCLES   (GLITCH_CYCLES),
	.MIN_HALF_CYCLES (MIN_HALF_CYCLES),
	.TIMEOUT_CYCLES  (TIMEOUT_CYCLES)
) u_tach (
	.clk        (clk),
	.rst        (rst),
	.tach_in    (tach_in),
	.rev_period (rev_period),
	.valid      (period_valid),
	.stalled    (stalled),
	.tach_clean (tach_clean)
);

wire [31:0] quotient;
wire [31:0] remainder_unused;
wire        div_busy, div_done;

seq_divider #(.WIDTH(32)) u_div (
	.clk       (clk),
	.rst       (rst),
	.start     (period_valid),
	.dividend  (RPM_NUMERATOR),
	.divisor   (rev_period),
	.quotient  (quotient),
	.remainder (remainder_unused),
	.busy      (div_busy),
	.done      (div_done)
);

always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		rpm       <= 16'd0;
		rpm_valid <= 1'b0;
	end
	else
	begin
		rpm_valid <= 1'b0;
		if (stalled == 1'b1)
			rpm <= 16'd0;
		else if (div_done == 1'b1)
		begin
			// saturate to 16 bits (a real fan never gets near 65535 RPM)
			if (quotient > 32'd65535)
				rpm <= 16'hFFFF;
			else
				rpm <= quotient[15:0];
			rpm_valid <= 1'b1;
		end
	end
end

endmodule

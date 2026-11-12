`timescale 1ns/1ps
// ============================================================================
// tach_period.v - measures how long one fan revolution takes
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
//
// The Noctua fan's tach wire gives 2 pulses per revolution (open collector,
// pulled up to 3.3 V). This module:
//   1. Synchronizes the tach input to CLOCK_50 (2 flip-flops) - the tach
//      signal is asynchronous, so without this we get metastability.
//   2. Glitch filter: the input must stay at a new level for GLITCH_CYCLES
//      clocks before we believe it (PWM switching noise causes spikes).
//   3. Times the gap between rising edges (one HALF revolution).
//   4. Adds two consecutive halves -> one FULL revolution. Using a full
//      revolution cancels the small asymmetry between the two magnet poles,
//      so the RPM reading doesn't jitter.
//   5. Rejects edges that come impossibly fast (MIN_HALF_CYCLES) and reports
//      "stalled" if no edge arrives for TIMEOUT_CYCLES.
//
// Output: rev_period (clk cycles per revolution) + 1-clk 'valid' pulse.
// RPM = 60 * 50e6 / rev_period = 3_000_000_000 / rev_period (see rpm_meter.v)
// ============================================================================
module tach_period #(
	parameter GLITCH_CYCLES   = 2500,       // 50 us at 50 MHz
	parameter MIN_HALF_CYCLES = 300000,     // 6 ms half-rev  -> >5000 RPM = noise
	parameter TIMEOUT_CYCLES  = 25000000    // 0.5 s with no edge -> stalled
)(
	input             clk,
	input             rst,          // active-low
	input             tach_in,      // raw pin (asynchronous)
	output reg [31:0] rev_period,   // clk cycles per full revolution
	output reg        valid,        // 1-clk pulse when rev_period updates
	output reg        stalled,      // 1 = no tach edges (fan stopped/unplugged)
	output            tach_clean    // filtered tach level (for an LED / debug)
);

/* ---------------- 1. two flip-flop synchronizer ---------------- */
reg sync1, sync2;
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		sync1 <= 1'b1;   // open-collector line idles high
		sync2 <= 1'b1;
	end
	else
	begin
		sync1 <= tach_in;
		sync2 <= sync1;
	end
end

/* ---------------- 2. glitch filter ---------------- */
reg        clean;
reg [15:0] glitch_cnt;
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		clean      <= 1'b1;
		glitch_cnt <= 16'd0;
	end
	else if (sync2 == clean)
		glitch_cnt <= 16'd0;                 // no change requested
	else if (glitch_cnt == GLITCH_CYCLES - 1)
	begin
		clean      <= sync2;                 // new level held long enough
		glitch_cnt <= 16'd0;
	end
	else
		glitch_cnt <= glitch_cnt + 16'd1;
end
assign tach_clean = clean;

/* rising-edge detect on the filtered signal */
reg  clean_d;
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
		clean_d <= 1'b1;
	else
		clean_d <= clean;
end
wire rise = (clean == 1'b1) && (clean_d == 1'b0);

/* ---------------- 3-5. half-period timer ---------------- */
reg [31:0] half_cnt;     // clocks since last accepted rising edge
reg [31:0] prev_half;    // previous half-revolution time
reg        have_prev;    // prev_half holds a real measurement

always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		half_cnt   <= 32'd0;
		prev_half  <= 32'd0;
		have_prev  <= 1'b0;
		rev_period <= 32'd0;
		valid      <= 1'b0;
		stalled    <= 1'b1;   // nothing measured yet
	end
	else
	begin
		valid <= 1'b0;        // default: valid is a 1-clk pulse

		if (rise == 1'b1 && stalled == 1'b1)
		begin
			// first edge after a stall: just start timing, no result yet
			half_cnt  <= 32'd0;
			have_prev <= 1'b0;
			stalled   <= 1'b0;
		end
		else if (rise == 1'b1 && half_cnt >= MIN_HALF_CYCLES)
		begin
			// a believable edge: one half revolution finished
			half_cnt  <= 32'd0;
			prev_half <= half_cnt;
			have_prev <= 1'b1;
			if (have_prev == 1'b1)
			begin
				rev_period <= half_cnt + prev_half;   // full revolution
				valid      <= 1'b1;
			end
		end
		else if (half_cnt >= TIMEOUT_CYCLES)
		begin
			// no edges for too long -> fan stopped
			stalled   <= 1'b1;
			have_prev <= 1'b0;
		end
		else
			half_cnt <= half_cnt + 32'd1;   // edges faster than MIN are ignored
	end
end

endmodule

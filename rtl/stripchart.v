`timescale 1ns/1ps
// ============================================================================
// stripchart.v - scrolling RPM graph on VGA                          [M2]
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
//
// What it draws (640 x 480):
//   - Measured RPM trace (green) and setpoint trace (yellow, enabled in M3)
//   - Horizontal grid every 200 RPM, vertical grid every 64 pixels
//   - 1 pixel = 4 RPM: 0 RPM at row 460, 1800 RPM at row 10
//   - Newest sample on the RIGHT, graph scrolls LEFT
//   - 640 samples at 20 Hz = 32 seconds of history on screen
//
// Memory: one 640 x 18-bit ring buffer in on-chip RAM (M10K block).
//   Each entry = {setpoint height[8:0], measured height[8:0]}, where
//   height = rpm / 4 (a shift, no divider), clamped to 460.
//   'head' points at the OLDEST sample (= the next one to overwrite).
//   While drawing column x we read entry (head + x) mod 640, so column 0 is
//   the oldest sample and column 639 the newest -> the graph scrolls.
//
// Pipeline (each stage advances on pix_en):
//   stage 0: x, y, active, syncs come in from vga_timing
//   stage 1: RAM read of column x  (RAM output is registered = 1 pixel late)
//   stage 2: pick the pixel color from the RAM data
// The syncs and 'active' are delayed through the SAME two stages, so the
// picture lines up with the sync pulses. (Skipping this delay is the classic
// VGA bug: the image shifts right by a couple of pixels.)
//
// Lines, not dots: each column is drawn from the previous column's height to
// this column's height, so steps in RPM show as solid vertical edges.
//
// Test pattern (test_pattern = 1): 8 color bars, 80 px wide, plus a 1-pixel
// white border. If the left or right border is missing on the monitor, the
// pipeline alignment is off.
// ============================================================================
module stripchart #(
	parameter SAMPLES = 640,
	parameter Y_ZERO  = 460,           // screen row for 0 RPM
	parameter H_MAX   = 460            // tallest trace height (rows above Y_ZERO)
)(
	input             clk,
	input             rst,             // active-low
	input             pix_en,
	// from vga_timing (stage 0)
	input             active,
	input             hsync_in,
	input             vsync_in,
	input      [9:0]  x,
	input      [9:0]  y,
	// data in
	input             sample_tick,     // 1-clk pulse: store a new sample
	input             pause,           // 1 = freeze the graph
	input             test_pattern,    // 1 = color bars (bring-up test)
	input             show_set,        // 1 = draw the setpoint trace
	input      [15:0] meas_rpm,
	input      [15:0] set_rpm,
	// to the VGA pins (stage 2, aligned)
	output reg [7:0]  r,
	output reg [7:0]  g,
	output reg [7:0]  b,
	output reg        hsync_out,
	output reg        vsync_out,
	output reg        blank_n          // 1 = visible pixel
);

/* ---------------- RPM -> trace height (1 px = 4 RPM) ---------------- */
function [8:0] rpm_to_h;
	input [15:0] rpm;
	begin
		if (rpm[15:2] > H_MAX)
			rpm_to_h = H_MAX;
		else
			rpm_to_h = rpm[10:2];
	end
endfunction

/* ---------------- writer: ring buffer head ---------------- */
reg  [9:0] head;                       // oldest sample = next write slot
wire       we = sample_tick & ~pause;

always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
		head <= 10'd0;
	else if (we == 1'b1)
	begin
		if (head == SAMPLES - 1)
			head <= 10'd0;
		else
			head <= head + 10'd1;
	end
end

/* ---------------- read address: (head + x) mod 640 ---------------- */
wire [9:0]  x_vis = (x < SAMPLES) ? x : 10'd0;   // stay in range during blanking
wire [10:0] sum   = {1'b0, head} + {1'b0, x_vis};
wire [9:0]  raddr = (sum >= SAMPLES) ? (sum - SAMPLES) : sum[9:0];

/* ---------------- ring buffer RAM ----------------
   Written as the Quartus simple-dual-port template so it maps to an M10K
   block. No reset here on purpose: RAM contents can't be reset in hardware. */
reg [17:0] mem [0:SAMPLES-1];
reg [17:0] rdata;                      // stage 1: {set_h, meas_h} for column x1

integer k;
initial begin
	for (k = 0; k < SAMPLES; k = k + 1)
		mem[k] = 18'd0;
	rdata = 18'd0;
end

always @(posedge clk)
begin
	if (we == 1'b1)
		mem[head] <= {rpm_to_h(set_rpm), rpm_to_h(meas_rpm)};
	if (pix_en == 1'b1)
		rdata <= mem[raddr];
end

/* ---------------- stage 1: delay position and syncs to match the RAM ---------------- */
reg [9:0] x1, y1;
reg       act1, hs1, vs1;

always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		x1 <= 10'd0;  y1 <= 10'd0;
		act1 <= 1'b0; hs1 <= 1'b1; vs1 <= 1'b1;
	end
	else if (pix_en == 1'b1)
	begin
		x1 <= x;      y1 <= y;
		act1 <= active; hs1 <= hsync_in; vs1 <= vsync_in;
	end
end

/* ---------------- stage 2 helpers (combinational) ---------------- */
reg [17:0] rprev;                      // previous column's RAM data

wire [8:0] meas_h      = rdata[8:0];
wire [8:0] set_h       = rdata[17:9];
wire [8:0] meas_h_prev = (x1 == 10'd0) ? meas_h : rprev[8:0];
wire [8:0] set_h_prev  = (x1 == 10'd0) ? set_h  : rprev[17:9];

// 1 if row yy lies on the line from the previous column to this column
// (2 px thick so flat lines are easy to see)
function on_trace;
	input [9:0] yy;
	input [8:0] h_cur;
	input [8:0] h_prev;
	reg   [9:0] y_cur, y_prev, lo, hi;
	begin
		y_cur  = Y_ZERO - h_cur;
		y_prev = Y_ZERO - h_prev;
		lo = (y_cur < y_prev) ? y_cur : y_prev;
		hi = (y_cur < y_prev) ? y_prev : y_cur;
		on_trace = (yy >= lo) && (yy <= hi + 10'd1);
	end
endfunction

// horizontal grid: every 50 rows = every 200 RPM (0, 200, ... 1800 RPM)
wire grid_h = (y1 == 10'd10)  || (y1 == 10'd60)  || (y1 == 10'd110) ||
              (y1 == 10'd160) || (y1 == 10'd210) || (y1 == 10'd260) ||
              (y1 == 10'd310) || (y1 == 10'd360) || (y1 == 10'd410);
wire axis   = (y1 == Y_ZERO) || (y1 == Y_ZERO + 1);
wire grid_v = (x1[5:0] == 6'd0) && (y1 >= 10'd10) && (y1 <= Y_ZERO);
wire mark_1000 = (y1 == 10'd210);      // 1000 RPM line drawn a bit brighter

wire hit_meas = on_trace(y1, meas_h, meas_h_prev) && (y1 <= Y_ZERO);
wire hit_set  = show_set && on_trace(y1, set_h, set_h_prev) && (y1 <= Y_ZERO);

/* test pattern: 8 bars of 80 px + 1 px white border */
reg  [2:0] bar;
always @(*)
begin
	if      (x1 < 10'd80)  bar = 3'd0;
	else if (x1 < 10'd160) bar = 3'd1;
	else if (x1 < 10'd240) bar = 3'd2;
	else if (x1 < 10'd320) bar = 3'd3;
	else if (x1 < 10'd400) bar = 3'd4;
	else if (x1 < 10'd480) bar = 3'd5;
	else if (x1 < 10'd560) bar = 3'd6;
	else                   bar = 3'd7;
end
wire border = (x1 == 10'd0) || (x1 == 10'd639) || (y1 == 10'd0) || (y1 == 10'd479);

/* ---------------- stage 2: choose the color (registered) ---------------- */
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		r <= 8'd0; g <= 8'd0; b <= 8'd0;
		hsync_out <= 1'b1; vsync_out <= 1'b1; blank_n <= 1'b0;
		rprev <= 18'd0;
	end
	else if (pix_en == 1'b1)
	begin
		hsync_out <= hs1;
		vsync_out <= vs1;
		blank_n   <= act1;
		rprev     <= rdata;

		if (act1 == 1'b0)
			{r, g, b} <= 24'h000000;              // must be black in blanking
		else if (test_pattern == 1'b1)
		begin
			if (border == 1'b1)
				{r, g, b} <= 24'hFFFFFF;
			else case (bar)
				3'd0: {r, g, b} <= 24'hFFFFFF;    // white
				3'd1: {r, g, b} <= 24'hFFFF00;    // yellow
				3'd2: {r, g, b} <= 24'h00FFFF;    // cyan
				3'd3: {r, g, b} <= 24'h00FF00;    // green
				3'd4: {r, g, b} <= 24'hFF00FF;    // magenta
				3'd5: {r, g, b} <= 24'hFF0000;    // red
				3'd6: {r, g, b} <= 24'h0000FF;    // blue
				default: {r, g, b} <= 24'h000000; // black
			endcase
		end
		else if (hit_meas == 1'b1)
			{r, g, b} <= 24'h20FF60;              // measured RPM: green
		else if (hit_set == 1'b1)
			{r, g, b} <= 24'hFFC000;              // setpoint: amber
		else if (axis == 1'b1)
			{r, g, b} <= 24'hA0A0A0;              // 0 RPM axis
		else if (mark_1000 == 1'b1)
			{r, g, b} <= 24'h505050;              // 1000 RPM reference
		else if (grid_h == 1'b1 || grid_v == 1'b1)
			{r, g, b} <= 24'h282828;              // grid
		else
			{r, g, b} <= 24'h000000;              // background
	end
end

endmodule

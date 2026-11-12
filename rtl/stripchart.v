`timescale 1ns/1ps
// ============================================================================
// stripchart.v - scrolling RPM graph on VGA               [SKELETON - M2]
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
//
// Two traces: setpoint (one color) and measured RPM (another color).
// Storage: one 640-entry ring buffer per trace in on-chip RAM
// (640 x 9 bits each - tiny). Every sample_tick, write the newest value at
// 'head' and advance head. While drawing column x, read sample
// [(head + x) mod 640] so the graph scrolls left.
//
// Scaling: plot area = 400 px tall. pixel_row = 440 - (rpm * 400 / 2000)
// (0 RPM at y=440, 2000 RPM at y=40). Use a shift/approx (rpm >> 2 is
// 0..500 px for 0..2000 RPM) to avoid a divider.
//
// TODO (M2):
//   1. Ring buffer RAM (IP Catalog "RAM: 2-PORT" or inferred template)
//   2. sample_tick writer: write meas/setpoint at head, head <= head + 1
//   3. Reader: address = head + x (wrap at 640), registered output
//   4. *** RAM read latency ***: data arrives 1-2 pix_en later than x/y.
//      Delay hsync/vsync/active by the same number of pixels, or the
//      traces will be shifted right. Most common VGA bug.
//   5. Pixel color: trace hit -> color; grid every 50 px -> dim gray;
//      outside active -> black
// ============================================================================
module stripchart (
	input            clk,
	input            rst,          // active-low
	input            pix_en,
	input            active,
	input      [9:0] x,
	input      [9:0] y,
	input            sample_tick,  // e.g. 20 Hz -> 640 samples = 32 s window
	input     [15:0] meas_rpm,
	input     [15:0] set_rpm,
	output reg [7:0] r,
	output reg [7:0] g,
	output reg [7:0] b
);

// TODO: implement ring buffers + pixel logic. Placeholder = black screen.
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		r <= 8'd0; g <= 8'd0; b <= 8'd0;
	end
	else if (pix_en == 1'b1)
	begin
		r <= 8'd0; g <= 8'd0; b <= 8'd0;
	end
end

endmodule

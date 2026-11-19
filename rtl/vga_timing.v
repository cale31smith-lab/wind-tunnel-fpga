`timescale 1ns/1ps
// ============================================================================
// vga_timing.v - 640x480 @ 60 Hz sync generator                      [M2]
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
//
// Pixel rate is 25 MHz = CLOCK_50 / 2. Instead of making a second clock, we
// make a 1-clk "pixel enable" (pix_en) that is high every other cycle, and
// only advance the counters on those cycles. Everything stays in the
// CLOCK_50 domain (no clock-domain crossing).
//
// Standard 640x480 @ 60 Hz timing (both syncs ACTIVE LOW):
//            visible  front porch  sync  back porch  total
//   H (px)     640        16        96       48       800
//   V (lines)  480        10         2       33       525
// 800 x 525 pixels x 60 Hz = 25.2 MHz; 25.0 MHz gives 59.5 Hz, which every
// monitor accepts.
//
// x, y   : registered counters (x = 0..799, y = 0..524)
// active : 1 when (x, y) is inside the visible 640x480 area
// hsync / vsync : decoded from the counters (re-registered in stripchart,
//                 so the pins never see decode glitches)
//
// VGA_CLK on the DE1-SoC: drive it with pix_en. The pixel pipeline updates on
// the edge where pix_en is high, so VGA_CLK's rising edge lands in the
// MIDDLE of each 40 ns pixel - the safest point for the video DAC to sample.
// ============================================================================
module vga_timing (
	input            clk,        // CLOCK_50
	input            rst,        // active-low
	output reg       pix_en,     // 25 MHz pixel enable (also drives VGA_CLK)
	output           hsync,      // active low
	output           vsync,      // active low
	output           active,     // 1 inside the visible 640x480 area
	output reg [9:0] x,          // 0..799 (visible when < 640)
	output reg [9:0] y           // 0..524 (visible when < 480)
);

parameter H_VISIBLE = 640, H_FRONT = 16, H_SYNC = 96, H_BACK = 48, H_TOTAL = 800;
parameter V_VISIBLE = 480, V_FRONT = 10, V_SYNC = 2,  V_BACK = 33, V_TOTAL = 525;

/* pixel enable: 1 every other clock -> 25 MHz */
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
		pix_en <= 1'b0;
	else
		pix_en <= ~pix_en;
end

/* horizontal and vertical counters */
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		x <= 10'd0;
		y <= 10'd0;
	end
	else if (pix_en == 1'b1)
	begin
		if (x == H_TOTAL - 1)
		begin
			x <= 10'd0;
			if (y == V_TOTAL - 1)
				y <= 10'd0;
			else
				y <= y + 10'd1;
		end
		else
			x <= x + 10'd1;
	end
end

/* sync and active-area decode */
assign hsync  = ~((x >= H_VISIBLE + H_FRONT) && (x < H_VISIBLE + H_FRONT + H_SYNC));
assign vsync  = ~((y >= V_VISIBLE + V_FRONT) && (y < V_VISIBLE + V_FRONT + V_SYNC));
assign active = (x < H_VISIBLE) && (y < V_VISIBLE);

endmodule

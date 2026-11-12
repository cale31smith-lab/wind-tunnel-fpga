`timescale 1ns/1ps
// ============================================================================
// vga_timing.v - 640x480 @ 60 Hz sync generator          [SKELETON - M2]
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
//
// Pixel clock: 25 MHz. Generate a 1-clk enable (pix_en) every other
// CLOCK_50 cycle rather than a second clock domain; drive VGA_CLK from it.
//
// Standard 640x480 @ 60 Hz timing (both syncs ACTIVE LOW):
//            visible  front porch  sync  back porch  total
//   H (px)     640        16        96       48       800
//   V (lines)  480        10         2       33       525
//
// TODO (M2):
//   1. pix_en toggles every clk (50 MHz / 2 = 25 MHz)
//   2. h_count 0..799 increments on pix_en; at 799 wrap and bump v_count
//   3. v_count 0..524
//   4. hsync = low when h_count in [656, 751]; vsync = low when v_count in [490, 491]
//   5. active = (h_count < 640) && (v_count < 480); x = h_count, y = v_count
//   6. Test with color bars (x[9:7] -> RGB) before connecting stripchart
// ============================================================================
module vga_timing (
	input            clk,        // CLOCK_50
	input            rst,        // active-low
	output reg       pix_en,     // 25 MHz pixel enable (also drives VGA_CLK)
	output reg       hsync,      // active low
	output reg       vsync,      // active low
	output reg       active,     // 1 inside the visible 640x480 area
	output reg [9:0] x,          // 0..799 (visible when < 640)
	output reg [9:0] y           // 0..524 (visible when < 480)
);

parameter H_VISIBLE = 640, H_FRONT = 16, H_SYNC = 96, H_BACK = 48, H_TOTAL = 800;
parameter V_VISIBLE = 480, V_FRONT = 10, V_SYNC = 2,  V_BACK = 33, V_TOTAL = 525;

// TODO: replace these placeholders with the counters described above
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		pix_en <= 1'b0;
		hsync  <= 1'b1;
		vsync  <= 1'b1;
		active <= 1'b0;
		x      <= 10'd0;
		y      <= 10'd0;
	end
	else
	begin
		pix_en <= ~pix_en;
	end
end

endmodule

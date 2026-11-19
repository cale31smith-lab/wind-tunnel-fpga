// ============================================================================
// tb_vga_timing.v - self-checking testbench for vga_timing
// Runs 2 full frames and checks, in pixels / lines:
//   - pix_en is high exactly every other clock (25 MHz)
//   - line = 800 px, hsync low for 96 px starting at x = 656
//   - frame = 525 lines, vsync low for 2 lines starting at y = 490
//   - exactly 640 x 480 active pixels per frame
// ============================================================================
`timescale 1ns/1ps
module tb_vga_timing;

reg  clk = 1'b0;
reg  rst = 1'b0;
wire pix_en, hsync, vsync, active;
wire [9:0] x, y;

always #10 clk = ~clk;

vga_timing dut (.clk(clk), .rst(rst), .pix_en(pix_en), .hsync(hsync),
                .vsync(vsync), .active(active), .x(x), .y(y));

integer errors = 0;
integer px, active_cnt, hs_low, hs_first, vs_low_lines, vs_first;
integer line_len, frame, pix_en_hi, clocks;
reg     prev_hs, prev_vs;

initial begin
	#55 rst = 1'b1;

	// --- pix_en duty: 1000 clocks -> exactly 500 high ---
	pix_en_hi = 0;
	for (clocks = 0; clocks < 1000; clocks = clocks + 1) begin
		@(posedge clk); if (pix_en) pix_en_hi = pix_en_hi + 1;
	end
	if (pix_en_hi != 500) begin
		$display("FAIL pix_en high %0d of 1000 clocks (expected 500)", pix_en_hi);
		errors = errors + 1;
	end else
		$display("ok   pix_en = 25 MHz (high every other clock)");

	// --- wait for the start of a frame (x = 0, y = 0) ---
	@(posedge clk); while (!(pix_en && x == 0 && y == 0)) @(posedge clk);

	for (frame = 0; frame < 2; frame = frame + 1) begin
		active_cnt = 0; vs_low_lines = 0; vs_first = -1;
		for (px = 0; px < 800 * 525; px = px + 1) begin
			// sample once per pixel (on pix_en cycles)
			@(posedge clk); while (!pix_en) @(posedge clk);
			if (active) active_cnt = active_cnt + 1;
			if (x == 0) begin
				if (!vsync) begin
					vs_low_lines = vs_low_lines + 1;
					if (vs_first < 0) vs_first = y;
				end
			end
			// check one line in detail (line 100)
			if (y == 100 && x == 0) begin hs_low = 0; hs_first = -1; line_len = 0; end
			if (y == 100) begin
				line_len = line_len + 1;
				if (!hsync) begin
					hs_low = hs_low + 1;
					if (hs_first < 0) hs_first = x;
				end
			end
		end
		if (active_cnt != 640 * 480) begin
			$display("FAIL frame %0d: %0d active pixels (expected 307200)", frame, active_cnt);
			errors = errors + 1;
		end
		if (hs_low != 96 || hs_first != 656 || line_len != 800) begin
			$display("FAIL hsync: low %0d px from x=%0d, line %0d px (expected 96 from 656, 800)",
			         hs_low, hs_first, line_len);
			errors = errors + 1;
		end
		if (vs_low_lines != 2 || vs_first != 490) begin
			$display("FAIL vsync: low %0d lines from y=%0d (expected 2 from 490)", vs_low_lines, vs_first);
			errors = errors + 1;
		end
		if (errors == 0)
			$display("ok   frame %0d: 307200 active px, hsync 96 px @656, vsync 2 lines @490, 800x525", frame);
	end

	if (errors == 0) $display("PASS tb_vga_timing");
	else             $display("FAIL tb_vga_timing (%0d errors)", errors);
	$finish;
end

endmodule

// ============================================================================
// tb_stripchart.v - self-checking testbench for vga_timing + stripchart
//
// Captures whole video frames exactly as the VGA DAC would see them and checks:
//   1. Sync alignment: after the pipeline delay, every visible line is
//      640 px, then 16 px front porch, 96 px hsync, 48 px back porch.
//   2. Test pattern: pixel 79 is white, pixel 80 is yellow (bar edge lands on
//      the exact pixel), border present on columns 0 and 639.
//   3. Graph: a known RPM sample appears at the right row and column, the
//      graph scrolls left when a new sample arrives, and 'pause' freezes it.
// It also writes two simulated screenshots (PPM images):
//   sim_testpattern.ppm, sim_graph.ppm
// ============================================================================
`timescale 1ns/1ps
module tb_stripchart;

reg  clk = 1'b0;
reg  rst = 1'b0;
always #10 clk = ~clk;

wire       pix_en, hs_raw, vs_raw, active;
wire [9:0] x, y;

vga_timing u_vga (.clk(clk), .rst(rst), .pix_en(pix_en), .hsync(hs_raw),
                  .vsync(vs_raw), .active(active), .x(x), .y(y));

reg         sample_tick = 1'b0;
reg         pause = 1'b0, test_pattern = 1'b1, show_set = 1'b0;
reg  [15:0] meas_rpm = 16'd0, set_rpm = 16'd0;
wire [7:0]  r, g, b;
wire        hsync_out, vsync_out, blank_n;

stripchart dut (
	.clk(clk), .rst(rst), .pix_en(pix_en),
	.active(active), .hsync_in(hs_raw), .vsync_in(vs_raw), .x(x), .y(y),
	.sample_tick(sample_tick), .pause(pause), .test_pattern(test_pattern),
	.show_set(show_set), .meas_rpm(meas_rpm), .set_rpm(set_rpm),
	.r(r), .g(g), .b(b), .hsync_out(hsync_out), .vsync_out(vsync_out), .blank_n(blank_n)
);

integer errors = 0;
reg [23:0] img [0:640*480-1];

/* ---------------- capture one frame from the OUTPUT pins ---------------- */
// Outputs change on clock edges where pix_en was 1; sampling on the falling
// clock edge while pix_en is 1 reads each pixel exactly once, mid-pixel.
integer row, col, done, prev_blank, bad_lines;
task capture_frame;
	begin
		@(negedge clk); while (vsync_out !== 1'b0) @(negedge clk);
		while (vsync_out !== 1'b1) @(negedge clk);
		row = 0; col = 0; done = 0; prev_blank = 0; bad_lines = 0;
		while (!done) begin
			@(negedge clk);
			if (pix_en) begin
				if (blank_n) begin
					if (col < 640) img[row*640 + col] = {r, g, b};
					col = col + 1;
				end
				if (prev_blank && !blank_n) begin
					if (col != 640) bad_lines = bad_lines + 1;
					row = row + 1; col = 0;
					if (row == 480) done = 1;
				end
				prev_blank = blank_n;
			end
		end
		if (bad_lines != 0) begin
			$display("FAIL %0d lines were not 640 px wide", bad_lines);
			errors = errors + 1;
		end
	end
endtask

/* ---------------- measure porch / sync widths on one output line ---------------- */
integer fp, sw, bp;
task check_hsync_alignment;
	begin
		// go to the end of a visible line
		@(negedge clk); while (!(pix_en && blank_n)) @(negedge clk);
		while (!(pix_en && !blank_n)) @(negedge clk);
		fp = 0; sw = 0; bp = 0;
		while (hsync_out) begin if (pix_en) fp = fp + 1; @(negedge clk); end
		while (!hsync_out) begin if (pix_en) sw = sw + 1; @(negedge clk); end
		while (!blank_n) begin if (pix_en) bp = bp + 1; @(negedge clk); end
		if (fp != 16 || sw != 96 || bp != 48) begin
			$display("FAIL output line timing: front %0d, sync %0d, back %0d (expected 16, 96, 48)", fp, sw, bp);
			errors = errors + 1;
		end else
			$display("ok   picture aligned to hsync: 640 px | 16 front | 96 sync | 48 back");
	end
endtask

/* ---------------- helpers ---------------- */
task expect_px(input integer yy, input integer xx, input [23:0] rgb, input [8*40-1:0] what);
	begin
		if (img[yy*640 + xx] !== rgb) begin
			$display("FAIL %0s: pixel (x=%0d, y=%0d) = %h, expected %h", what, xx, yy, img[yy*640 + xx], rgb);
			errors = errors + 1;
		end else
			$display("ok   %0s: (x=%0d, y=%0d) = %h", what, xx, yy, rgb);
	end
endtask

task push_sample(input [15:0] meas, input [15:0] setp);
	begin
		@(negedge clk);
		meas_rpm = meas; set_rpm = setp; sample_tick = 1'b1;
		@(negedge clk);
		sample_tick = 1'b0;
	end
endtask

integer fd, i;
task dump_ppm(input [8*32-1:0] fname);
	begin
		fd = $fopen(fname, "w");
		$fwrite(fd, "P3\n640 480\n255\n");
		for (i = 0; i < 640*480; i = i + 1)
			$fwrite(fd, "%0d %0d %0d\n", img[i][23:16], img[i][15:8], img[i][7:0]);
		$fclose(fd);
	end
endtask

/* realistic data: setpoint steps, fan follows with a 0.6 s lag (12 samples at 20 Hz) */
real    rpm_now, target, noise;
integer s, seed;
reg [15:0] sp;

localparam [23:0] GREEN = 24'h20FF60, WHITE = 24'hFFFFFF, YELLOW = 24'hFFFF00, BLACK = 24'h000000;

initial begin
	seed = 7;
	#55 rst = 1'b1;

	/* ---- 1. test pattern + alignment ---- */
	check_hsync_alignment;
	capture_frame;
	expect_px(1,   0, WHITE,  "left border");
	expect_px(1, 639, WHITE,  "right border");
	expect_px(1, 638, BLACK,  "last bar (black)");
	expect_px(240, 79, WHITE, "bar 0 last px");
	expect_px(240, 80, YELLOW,"bar 1 first px");
	dump_ppm("sim_testpattern.ppm");

	/* ---- 2. graph: fill 640 samples (one full screen) ---- */
	test_pattern = 1'b0;
	show_set     = 1'b1;          // show both traces in the screenshot (M3 look)
	rpm_now = 929.0;
	for (s = 0; s < 640; s = s + 1) begin
		if      (s < 120) sp = 16'd929;    // 50% duty
		else if (s < 300) sp = 16'd1505;   // step up
		else if (s < 460) sp = 16'd760;    // step down
		else              sp = 16'd1240;
		target  = sp;
		rpm_now = rpm_now + (target - rpm_now) / 12.0;
		noise   = ($random(seed) % 7);
		push_sample($rtoi(rpm_now + noise), sp);
	end
	capture_frame;
	dump_ppm("sim_graph.ppm");

	// after exactly 640 samples head = 0, so column x shows sample x.
	// Sample 50 is in the flat 929 RPM region; set trace = 929 -> h = 232 -> row 228.
	// measured trace at column 50 must be green somewhere in rows 226..231
	if (img[228*640 + 50] !== GREEN && img[229*640 + 50] !== GREEN &&
	    img[227*640 + 50] !== GREEN && img[230*640 + 50] !== GREEN) begin
		$display("FAIL measured trace missing near row 228 at column 50");
		errors = errors + 1;
	end else
		$display("ok   929 RPM drawn at row ~228 (1 px = 4 RPM, 0 RPM at row 460)");
	expect_px(440, 50, BLACK, "empty space below trace");

	/* ---- 3. scrolling: one new sample at 1800 RPM appears at the right edge ---- */
	show_set = 1'b0;
	push_sample(16'd1800, 16'd0);              // h = 450 -> rows 10..11
	capture_frame;
	expect_px(10, 639, GREEN, "newest sample at right edge");

	/* ---- 4. pause: new samples must NOT be stored ---- */
	pause = 1'b1;
	for (s = 0; s < 20; s = s + 1) push_sample(16'd0, 16'd0);
	capture_frame;
	expect_px(10, 639, GREEN, "graph frozen while paused");

	if (errors == 0) $display("PASS tb_stripchart");
	else             $display("FAIL tb_stripchart (%0d errors)", errors);
	$finish;
end

endmodule

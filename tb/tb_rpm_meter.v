// ============================================================================
// tb_rpm_meter.v - self-checking testbench for rpm_meter (tach -> RPM)
// Uses the REAL 50 MHz constants, so this also proves the numbers in
// rpm_meter.v are right. Drives an ideal tach signal with:
//   - 3% asymmetry between the two pulses per rev (real magnets)
//   - 100 ns noise spikes injected every few ms (PWM coupling)
// Checks the RPM at 1700, 1000 and 550 RPM, then that a stopped fan
// reads 0 and raises 'stalled'.
// ============================================================================
`timescale 1ns/1ps
module tb_rpm_meter;

reg  clk = 1'b0;
reg  rst = 1'b0;
reg  tach_ideal = 1'b1;
reg  spike = 1'b0;
wire tach_in = tach_ideal ^ spike;   // noise flips the line briefly

wire [15:0] rpm;
wire        rpm_valid, stalled, tach_clean;

always #10 clk = ~clk;

rpm_meter dut (
	.clk(clk), .rst(rst), .tach_in(tach_in),
	.rpm(rpm), .rpm_valid(rpm_valid), .stalled(stalled), .tach_clean(tach_clean)
);

/* ideal tach generator */
real    sim_rpm = 0.0;
real    half_ns;
integer pole = 0;
initial begin
	forever begin
		if (sim_rpm < 1.0) #100_000;
		else begin
			half_ns = 30.0e9 / sim_rpm * ((pole == 0) ? 1.03 : 0.97);
			pole = 1 - pole;
			tach_ideal = 1'b0; #(half_ns / 2.0);
			tach_ideal = 1'b1; #(half_ns / 2.0);
		end
	end
end

/* noise spikes: 100 ns wide, every 3.3 ms */
initial begin
	forever begin
		#3_300_000 spike = 1'b1;
		#100       spike = 1'b0;
	end
end

integer errors = 0;
integer diff;

task check_speed(input real target, input integer expected);
	begin
		sim_rpm = target;
		repeat (4) @(posedge rpm_valid);     // flush old measurements
		@(posedge clk);
		diff = rpm - expected;
		if (diff < -2 || diff > 2) begin
			$display("FAIL %0.0f RPM -> measured %0d (expected %0d +/-2)", target, rpm, expected);
			errors = errors + 1;
		end
		else
			$display("ok   %4.0f RPM -> measured %0d", target, rpm);
	end
endtask

initial begin
	#55 rst = 1'b1;

	check_speed(1700.0, 1700);
	check_speed(1000.0, 1000);
	check_speed(550.0,  550);

	sim_rpm = 0.0;                           // fan stops
	#700_000_000;                            // 0.7 s > 0.5 s timeout
	if (stalled !== 1'b1 || rpm !== 16'd0) begin
		$display("FAIL stopped fan -> stalled=%b rpm=%0d (expected 1, 0)", stalled, rpm);
		errors = errors + 1;
	end
	else
		$display("ok   stopped fan -> stalled=1, rpm=0");

	check_speed(1200.0, 1200);               // recovers after a stall

	if (errors == 0) $display("PASS tb_rpm_meter");
	else             $display("FAIL tb_rpm_meter (%0d errors)", errors);
	$finish;
end

endmodule

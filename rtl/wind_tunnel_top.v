`timescale 1ns/1ps
// ============================================================================
// wind_tunnel_top.v - top level for the DE1-SoC
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
// Team: James Wood, Cale Smith
// Board: DE1-SoC, Cyclone V 5CSEMA5F31C6, CLOCK_50 = 50 MHz
// Fan:   Noctua NF-P12 redux-1700 PWM (1700 RPM max, ~550 RPM at 20% PWM,
//        2 tach pulses per revolution, open-collector tach)
//
// ---------------------------------------------------------------------------
// MILESTONE M1 (this version): open-loop fan control + live RPM readout
//   SW[6:0]  = duty cycle in percent (0..99, values above 99 clamp to 99)
//   SW[9]    = force 100% (full speed)
//   KEY[0]   = reset (active-low, course convention)
//   HEX3..0  = measured RPM (leading zeros blanked, updates 4x per second)
//   HEX5..4  = duty % ("FF" when SW[9] forces full speed)
//   LEDR[0]  = filtered tach signal (flickers when the fan spins)
//   LEDR[1]  = fan stalled / no tach signal
//   LEDR[2]  = toggles every new RPM measurement
//   LEDR[9]  = PWM output (brightness roughly follows duty)
//
// Planned later milestones plug in where marked "M2+" below:
//   M2: vga_timing + stripchart      M3: pid_controller + mode_fsm
//   M4: step_test                    M5: autotune
// ============================================================================
module wind_tunnel_top #(
	// 0 = FPGA pin drives the fan's PWM wire directly (push-pull, Noctua's
	//     recommended drive). ONLY if the fan's PWM pin measures <= 3.3 V
	//     with the fan powered and the wire unconnected (see README).
	// 1 = external NPN/N-MOSFET stage between the FPGA and the fan (needed if
	//     the fan pulls PWM up to 5 V). The transistor inverts, so we invert.
	parameter PWM_INVERT    = 1'b0,
	parameter DISPLAY_TICKS = 12500000   // 4 Hz display refresh at 50 MHz
)(
	//////////// CLOCK //////////
	input         CLOCK_50,

	//////////// KEY / SW / LED //////////
	input  [3:0]  KEY,
	input  [9:0]  SW,
	output [9:0]  LEDR,

	//////////// SEG7 //////////
	output [6:0]  HEX0,
	output [6:0]  HEX1,
	output [6:0]  HEX2,
	output [6:0]  HEX3,
	output [6:0]  HEX4,
	output [6:0]  HEX5,

	//////////// FAN (GPIO_0 header) //////////
	output        FAN_PWM,     // GPIO_0[0]
	input         FAN_TACH,    // GPIO_0[1]

	//////////// VGA (used from M2 on) //////////
	output [7:0]  VGA_R,
	output [7:0]  VGA_G,
	output [7:0]  VGA_B,
	output        VGA_CLK,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_BLANK_N,
	output        VGA_SYNC_N
);

/* ---------------- board signal names ---------------- */
wire clk = CLOCK_50;
wire rst = KEY[0];          // active-low reset

/* ---------------- duty cycle from the switches (M1 open loop) ---------------- */
reg  [6:0]  duty_pct;       // 0..100
reg  [10:0] duty;           // 0..2000 PWM counts (20 counts per percent)

always @(*)
begin
	if (SW[9] == 1'b1)
		duty_pct = 7'd100;
	else if (SW[6:0] > 7'd99)
		duty_pct = 7'd99;
	else
		duty_pct = SW[6:0];

	duty = duty_pct * 11'd20;
	// M2+: in closed-loop mode this becomes the PID controller's output
end

/* ---------------- PWM generator ---------------- */
wire pwm;
wire pwm_period_start;

pwm_gen #(.PERIOD(2000)) u_pwm (
	.clk          (clk),
	.rst          (rst),
	.duty         (duty),
	.pwm          (pwm),
	.period_start (pwm_period_start)
);

assign FAN_PWM = (PWM_INVERT == 1'b1) ? ~pwm : pwm;

/* ---------------- RPM measurement ---------------- */
wire [15:0] rpm;
wire        rpm_valid;
wire        stalled;
wire        tach_clean;

rpm_meter u_rpm (
	.clk        (clk),
	.rst        (rst),
	.tach_in    (FAN_TACH),
	.rpm        (rpm),
	.rpm_valid  (rpm_valid),
	.stalled    (stalled),
	.tach_clean (tach_clean)
);

/* ---------------- display refresh (4 Hz so digits are readable) ---------------- */
reg [23:0] disp_cnt;
reg [15:0] rpm_disp;
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		disp_cnt <= 24'd0;
		rpm_disp <= 16'd0;
	end
	else if (disp_cnt == DISPLAY_TICKS - 1)
	begin
		disp_cnt <= 24'd0;
		rpm_disp <= rpm;
	end
	else
		disp_cnt <= disp_cnt + 24'd1;
end

/* toggle an LED on every new measurement */
reg meas_led;
always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
		meas_led <= 1'b0;
	else if (rpm_valid == 1'b1)
		meas_led <= ~meas_led;
end

/* ---------------- seven-segment displays ---------------- */
four_decimal_vals u_rpm_disp (
	.val       (rpm_disp),
	.seg7_dig0 (HEX0),
	.seg7_dig1 (HEX1),
	.seg7_dig2 (HEX2),
	.seg7_dig3 (HEX3)
);

wire [6:0] pct_dig0, pct_dig1;
two_decimal_vals u_pct_disp (
	.val       (duty_pct),
	.seg7_dig0 (pct_dig0),
	.seg7_dig1 (pct_dig1)
);

wire [6:0] seg_F = 7'b0001110;     // "F" for full speed
assign HEX4 = (SW[9] == 1'b1) ? seg_F : pct_dig0;
assign HEX5 = (SW[9] == 1'b1) ? seg_F : pct_dig1;

/* ---------------- LEDs ---------------- */
assign LEDR[0]   = tach_clean;
assign LEDR[1]   = stalled;
assign LEDR[2]   = meas_led;
assign LEDR[8:3] = 6'd0;
assign LEDR[9]   = pwm;

/* ---------------- VGA: idle until M2 ---------------- */
// M2+: replace with vga_timing + stripchart outputs
assign VGA_R       = 8'd0;
assign VGA_G       = 8'd0;
assign VGA_B       = 8'd0;
assign VGA_CLK     = 1'b0;
assign VGA_HS      = 1'b1;
assign VGA_VS      = 1'b1;
assign VGA_BLANK_N = 1'b0;
assign VGA_SYNC_N  = 1'b0;

endmodule

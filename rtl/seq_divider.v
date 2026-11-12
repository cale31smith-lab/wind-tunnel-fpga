`timescale 1ns/1ps
// ============================================================================
// seq_divider.v - sequential (one bit per clock) unsigned divider
// ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller
//
// Same idea as Lab 11's sequential pop count: instead of one huge
// combinational divider (lots of logic, slow), reuse ONE subtractor for
// WIDTH clock cycles. Restoring long division, like division by hand:
//
//   for i = WIDTH-1 downto 0:
//       remainder = (remainder << 1) | dividend[i]
//       if remainder >= divisor: remainder -= divisor, quotient[i] = 1
//
// Timing: start (1 clk) -> WIDTH clks of work -> done pulse.
// 32-bit divide = 34 clocks = 0.68 us at 50 MHz (tach updates every ~35 ms,
// so speed is no issue).
// Divide by zero returns quotient = all 1s (caller should avoid it).
// ============================================================================
module seq_divider #(
	parameter WIDTH = 32
)(
	input                  clk,
	input                  rst,        // active-low
	input                  start,      // 1-clk pulse: latch inputs and begin
	input      [WIDTH-1:0] dividend,
	input      [WIDTH-1:0] divisor,
	output reg [WIDTH-1:0] quotient,
	output reg [WIDTH-1:0] remainder,
	output reg             busy,
	output reg             done        // 1-clk pulse when quotient is valid
);

reg [1:0] S;
parameter IDLE   = 2'd0,
          DIVIDE = 2'd1,
          FINISH = 2'd2;

reg [WIDTH-1:0] dvd;       // dividend being shifted out (MSb first)
reg [WIDTH-1:0] dvs;       // latched divisor
reg [5:0]       bit_cnt;   // iterations remaining

/* shifted remainder for this iteration (WIDTH+1 bits so no overflow) */
wire [WIDTH:0]  rem_shift = {remainder, dvd[WIDTH-1]};
wire            fits      = (rem_shift >= {1'b0, dvs});

always @(posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		S         <= IDLE;
		dvd       <= {WIDTH{1'b0}};
		dvs       <= {WIDTH{1'b0}};
		quotient  <= {WIDTH{1'b0}};
		remainder <= {WIDTH{1'b0}};
		bit_cnt   <= 6'd0;
		busy      <= 1'b0;
		done      <= 1'b0;
	end
	else
	begin
		done <= 1'b0;
		case (S)
			IDLE: begin
				if (start == 1'b1)
				begin
					dvd       <= dividend;
					dvs       <= divisor;
					quotient  <= {WIDTH{1'b0}};
					remainder <= {WIDTH{1'b0}};
					bit_cnt   <= WIDTH;
					busy      <= 1'b1;
					S         <= DIVIDE;
				end
			end

			DIVIDE: begin
				// one long-division step per clock
				if (fits == 1'b1)
					remainder <= rem_shift[WIDTH-1:0] - dvs;
				else
					remainder <= rem_shift[WIDTH-1:0];
				quotient <= {quotient[WIDTH-2:0], fits};
				dvd      <= {dvd[WIDTH-2:0], 1'b0};
				bit_cnt  <= bit_cnt - 6'd1;
				if (bit_cnt == 6'd1)
					S <= FINISH;
			end

			FINISH: begin
				busy <= 1'b0;
				done <= 1'b1;
				S    <= IDLE;
			end

			default: S <= IDLE;
		endcase
	end
end

endmodule

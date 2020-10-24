module BlockChecker(
	input clk,
	input reset,
	input [7:0] in,
	output result
);
	wire is_upper = in >= "A" && in <= "Z";
	wire [7:0] in_lower = is_upper ? in | 8'h20 : in;
	reg [3:0] state;
	reg [31:0] depth;
	wire [31:0] new_dpeth = $signed(depth) < 0 ? depth : state == 5 ? $signed(depth) + 1 : state == 8 ? $signed(depth) - 1 : depth;
	assign result = new_dpeth == 0;

	always @(posedge clk, posedge reset) begin
		if (reset) begin
			state <= 0;
			depth <= 0;
		end else begin
			case (state)
			0:
				if (in_lower == "b") state <= 1;
				else if (in_lower == "e") state <= 6;
				else if (in_lower == " ") state <= 0;
				else state <= 9;
			1:
				if (in_lower == "e") state <= 2;
				else if (in_lower == " ") state <= 0;
				else state <= 9;
			2:
				if (in_lower == "g") state <= 3;
				else if (in_lower == " ") state <= 0;
				else state <= 9;
			3:
				if (in_lower == "i") state <= 4;
				else if (in_lower == " ") state <= 0;
				else state <= 9;
			4:
				if (in_lower == "n") state <= 5;
				else if (in_lower == " ") state <= 0;
				else state <= 9;
			5:
				if (in_lower == " ") begin
					depth <= new_dpeth;
					state <= 0;
				end else state <= 9;
			6:
				if (in_lower == "n") state <= 7;
				else if (in_lower == " ") state <= 0;
				else state <= 9;
			7:
				if (in_lower == "d") state <= 8;
				else if (in_lower == " ") state <= 0;
				else state <= 9;
			8:
				if (in_lower == " ") begin
					depth <= new_dpeth;
					state <= 0;
				end else state <= 9;
			default:
				if (in_lower == " ") state <= 0;
				else state <= 9;
			endcase
		end
	end
endmodule

module BlockChecker_test();
	reg clk = 0, reset;
	reg [7:0] in;
	wire result;

	BlockChecker uut(clk, reset, in, result);

	always #5 clk = ~clk;

	localparam DATA_LEN = 10;
	wire [(DATA_LEN << 3) - 1 : 0] input_data = "bEgIn EnD ";

	integer i;
	initial begin
`ifdef DUMPFILE
		$dumpfile(`DUMPFILE);
		$dumpvars(0, BlockChecker_test);
`endif
		reset = 1;
		#10;
		reset = 0;
		for (i = DATA_LEN - 1; i >= 0; i = i - 1) begin
			in = input_data[i << 3 +: 8];
			#10;
		end
		#50;
		$finish();
	end
endmodule

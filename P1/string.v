module string(
	input clk,
	input clr,
	input [7:0] in,
	output out
);
	reg [1:0] state = 0;
	assign out = state == 1;
	wire isdigit = in >= "0" && in <= "9";
	wire isop = in == "+" || in == "*";
	always @(posedge clk, posedge clr) begin
		if (clr) state <= 0;
		else begin
			case (state)
				0: begin
					if (isdigit) state <= 1;
					else state <= 2;
				end
				1: begin
					if (isop) state <= 0;
					else state <= 2;
				end
				default: state <= 2;
			endcase
		end
	end
endmodule

module string_test();
	reg clk = 0, clr = 0;
	reg [7:0] in;
	wire out;

	string uut(clk, clr, in, out);

	always #5 clk = ~clk;

	initial begin
`ifdef DUMPFILE
		$dumpfile(`DUMPFILE);
		$dumpvars(0, string_test);
`endif
		in = "1";
		#10;
		in = "+";
		#10;
		in = "2";
		#20;
		in = "*";
		#10;
		in = "3";
		#10;
		in = "a";
		#10;
		clr = 1;
		#10;
		clr = 0;
		in = "1";
		#10;
		in = "+";
		#30;

		$finish();
	end
endmodule

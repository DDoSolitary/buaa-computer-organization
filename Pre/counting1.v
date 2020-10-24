module counting(
	input [1:0] num,
	input clk,
	output ans
);
	reg [1:0] state = 0;
	assign ans = state == 3;

	always @(posedge clk) begin
		if (state != 3) begin
			case (num)
			1: state <= 1;
			2: begin
				if (state == 1) state <= 2;
				else state <= 0;
			end
			3: begin
				if (state == 2) state <= 3;
				else state <= 0;
			end
			endcase
		end
	end
endmodule

module counting_test;
	reg clk = 1;
	reg [1:0] num;
	wire ans;

	counting uut(num, clk, ans);

	always #5 clk = ~clk;

	initial begin
`ifdef DUMPFILE
		$dumpfile(`DUMPFILE);
		$dumpvars(0, counting_test);
`endif
		#10;
		num = 1;
		#10;
		num = 2;
		#10;
		num = 1;
		#10;
		num = 2;
		#10;
		num = 3;
		#10;
		num = 1;
		#30;
		$finish();
	end
endmodule

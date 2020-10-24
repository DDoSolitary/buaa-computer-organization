module code(
	input Clk,
	input Reset,
	input Slt,
	input En,
	output reg [63:0] Output0 = 0,
	output reg [63:0] Output1 = 0
);
	reg [1:0] state = 0;

	always @(posedge Clk) begin
		if (Reset) begin
			Output0 <= 0;
			Output1 <= 0;
			state <= 0;
		end else if (En) begin
			if (Slt) begin
				if (state == 3) Output1 <= Output1 +1;
				state <= state +1;
			end else begin
				Output0 <= Output0 + 1;
			end
		end
	end
endmodule

module code_test;
	reg Clk = 1;
	reg Reset = 0;
	reg Slt = 0;
	reg En = 1;
	wire [63:0] Output0;
	wire [63:0] Output1;

	code uut(Clk, Reset, Slt, En, Output0, Output1);

	always #5 Clk = ~Clk;

	initial begin
`ifdef DUMPFILE
		$dumpfile(`DUMPFILE);
		$dumpvars(0, code_test);
`endif
		Slt = 1;
		#200;
		$finish();
	end
endmodule

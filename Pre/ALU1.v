module ALU(
	input [3:0] inA,
	input [3:0] inB,
	input [1:0] op,
	output [3:0] ans
);
	assign ans =
		{4{op == 2'b00}} & (inA & inB) |
		{4{op == 2'b01}} & (inA | inB) |
		{4{op == 2'b10}} & (inA ^ inB) |
		{4{op == 2'b11}} & (inA + inB);
endmodule

module ALU_test;
	reg [3:0] inA;
	reg [3:0] inB;
	reg [1:0] op;
	wire [3:0] ans;

	ALU uut(inA, inB, op, ans);

	initial begin
`ifdef DUMPFILE
		$dumpfile(`DUMPFILE);
		$dumpvars(0, ALU_test);
`endif
		inA = 2;
		inB = 3;
		op = 2'b11;
		#10;
		$display("ans: %d", ans);
	end
endmodule

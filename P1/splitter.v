module splitter(
	input [31:0] A,
	output [7:0] O1,
	output [7:0] O2,
	output [7:0] O3,
	output [7:0] O4
);
	assign O1 = A[31:24];
	assign O2 = A[23:16];
	assign O3 = A[15:8];
	assign O4 = A[7:0];
endmodule

module splitter_test;
	reg [31:0] A;
	wire [7:0] O1, O2, O3, O4;

	splitter uut(A, O1, O2, O3, O4);

	initial begin
`ifdef DUMPFILE
		$dumpfile(`DUMPFILE);
		$dumpvars(0, splitter_test);
`endif
		A = 'h10203040;
		#10;
		$display("O1: %d", O1);
		$display("O2: %d", O2);
		$display("O3: %d", O3);
		$display("O4: %d", O4);
	end
endmodule

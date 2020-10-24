module alu(
	input [31:0] A,
	input [31:0] B,
	input [2:0] ALUOp,
	output reg [31:0] C
);
	always @(A, B, ALUOp) begin
		case (ALUOp)
			3'b000: C <= A + B;
			3'b001: C <= A - B;
			3'b010: C <= A & B;
			3'b011: C <= A | B;
			3'b100: C <= A >> B;
			3'b101: C <= $signed(A) >>> B;
			default: C <= 0;
		endcase
	end
endmodule

module alu_test();
	reg [31:0] A, B;
	reg [2:0] ALUOp;
	wire [31:0] C;

	alu uut(A, B, ALUOp, C);

	initial begin
`ifdef DUMPFILE
		$dumpfile(`DUMPFILE);
		$dumpvars(0, alu_test);
`endif
		A = 1;
		B = 2;
		ALUOp = 3'b000;
		#10;
		$display("A + B = %d", C);
	end
endmodule

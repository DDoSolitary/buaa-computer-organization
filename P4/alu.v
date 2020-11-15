`include "constants.v"

module alu(
	input [31:0] in0,
	input [31:0] in1,
	input [2:0] op,
	output reg [31:0] out
);
	always @*
		case (op)
			`ALU_OP_ADD: out = in0 + in1;
			`ALU_OP_SUB: out = in0 - in1;
			`ALU_OP_OR: out = in0 | in1;
			`ALU_OP_EQ: out = in0 == in1;
			`ALU_OP_SL16: out = in1 << 16;
			default: out = 0;
		endcase
endmodule

module alu_test(input start, output reg stop = 0);
	reg [31:0] in0, in1;
	reg [2:0] op;
	wire [31:0] out;

	alu uut(in0, in1, op, out);

	always @(posedge start) begin
		$display("--- alu_test start ---");
		in0 = 'h123456;
		in1 = 'h654321;
		op = `ALU_OP_ADD;
		#1;
		$display("add: %h", out);
		op = `ALU_OP_SUB;
		#1;
		$display("sub: %h", out);
		op = `ALU_OP_OR;
		#1;
		$display("or: %h", out);
		op = `ALU_OP_EQ;
		#1;
		$display("eq: %h", out);
		op = `ALU_OP_SL16;
		#1;
		$display("shift: %h", out);
		$display("--- alu_test stop ---\n");
		stop = 1;
	end
endmodule

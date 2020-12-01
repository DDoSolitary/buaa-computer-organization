`include "def.v"

module stage_execute(
	input wire [31:0] grf_in0,
	input wire [31:0] grf_in1,
	input wire alu_src1,
	input wire [1:0] alu_op,
	input wire [31:0] ext_imm,
	output wire [31:0] alu_result
);
	wire [31:0] in0 = grf_in0;
	wire [31:0] in1 = alu_src1 == `ALU_SRC1_RT ? grf_in1 : ext_imm;

	assign alu_result =
		alu_op == `ALU_OP_ADD ? in0 + in1 :
		alu_op == `ALU_OP_SUB ? in0 - in1 :
		alu_op == `ALU_OP_OR ? in0 | in1 :
		alu_op == `ALU_OP_SL16 ? in1 << 16 : 0;
endmodule

`include "def.v"

module stage_execute(
	input wire [31:0] grf_in0,
	input wire [31:0] grf_in1,
	input wire alu_src0,
	input wire alu_src1,
	input wire [`ALU_OP_LEN - 1:0] alu_op,
	input wire [31:0] ext_imm,
	input wire [4:0] sa,
	output wire [31:0] alu_result
);
	wire [31:0] in0 = alu_src0 == `ALU_SRC0_RS ? grf_in0 : sa;
	wire [31:0] in1 = alu_src1 == `ALU_SRC1_RT ? grf_in1 : ext_imm;

	wire [31:0] sra_result = $signed(in1) >>> in0[4:0];

	assign alu_result =
		alu_op == `ALU_OP_ADD ? in0 + in1 :
		alu_op == `ALU_OP_SUB ? in0 - in1 :
		alu_op == `ALU_OP_AND ? in0 & in1 :
		alu_op == `ALU_OP_OR ? in0 | in1 :
		alu_op == `ALU_OP_XOR ? in0 ^ in1 :
		alu_op == `ALU_OP_NOR ? ~(in0 | in1) :
		alu_op == `ALU_OP_SLL ? in1 << in0[4:0] :
		alu_op == `ALU_OP_SRL ? in1 >> in0[4:0] :
		alu_op == `ALU_OP_SRA ? sra_result : 0;
endmodule

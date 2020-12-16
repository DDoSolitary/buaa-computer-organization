`include "def.v"

module stage_execute(
	input wire [31:0] grf_in0,
	input wire [31:0] grf_in1,
	input wire alu_src0,
	input wire alu_src1,
	input wire [`ALU_OP_LEN - 1:0] alu_op,
	input wire [31:0] ext_imm,
	input wire [4:0] sa,
	output wire [31:0] alu_result,
	output wire overflowed
);
	wire [31:0] in0 = alu_src0 == `ALU_SRC0_RS ? grf_in0 : sa;
	wire [31:0] in1 = alu_src1 == `ALU_SRC1_RT ? grf_in1 : ext_imm;

	wire [32:0] ext_in0 = {in0[31], in0};
	wire [32:0] ext_in1 = {in1[31], in1};

	wire [32:0] add_result = ext_in0 + ext_in1;
	wire [32:0] sub_result = ext_in0 - ext_in1;
	wire [31:0] sra_result = $signed(in1) >>> in0[4:0];
	wire [31:0] slt_result = $signed(in0) < $signed(in1);

	assign overflowed =
		alu_op == `ALU_OP_ADD && add_result[32] != add_result[31] ||
		alu_op == `ALU_OP_SUB && sub_result[32] != sub_result[31];

	assign alu_result =
		alu_op == `ALU_OP_ADD ? add_result[31:0] :
		alu_op == `ALU_OP_SUB ? sub_result[31:0] :
		alu_op == `ALU_OP_AND ? in0 & in1 :
		alu_op == `ALU_OP_OR ? in0 | in1 :
		alu_op == `ALU_OP_XOR ? in0 ^ in1 :
		alu_op == `ALU_OP_NOR ? ~(in0 | in1) :
		alu_op == `ALU_OP_SLL ? in1 << in0[4:0] :
		alu_op == `ALU_OP_SRL ? in1 >> in0[4:0] :
		alu_op == `ALU_OP_SRA ? sra_result :
		alu_op == `ALU_OP_SLT ? slt_result :
		alu_op == `ALU_OP_SLTU ? in0 < in1 : 0;
endmodule

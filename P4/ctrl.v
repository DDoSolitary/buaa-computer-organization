`include "constants.v"

module ctrl(
	input [5:0] op,
	input [5:0] func,
	output reg_write,
	output [1:0] reg_dst,
	output [1:0] reg_data,
	output alu_src,
	output [2:0] alu_op,
	output mem_write,
	output [1:0] jump_mode,
	output ext_op
);
	wire op_sp = op == 6'b000000;
	wire addu = op_sp && func == 6'b100001;
	wire subu = op_sp && func == 6'b100011;
	wire ori = op == 6'b001101;
	wire lw = op == 6'b100011;
	wire sw = op == 6'b101011;
	wire beq = op == 6'b000100;
	wire lui = op == 6'b001111;
	wire jal = op == 6'b000011;
	wire jr = op_sp && func == 6'b001000;

	assign reg_write = addu || subu || ori || lw || lui || jal;
	assign reg_dst =
		addu || subu ? `REG_DST_RD :
		ori || lw || lui ? `REG_DST_RT :
		jal ? `REG_DST_RA : 0;
	assign reg_data =
		addu || subu || ori || lui ? `REG_DATA_ALU :
		lw ? `REG_DATA_MEM :
		jal ? `REG_DATA_PC4 : 0;
	assign alu_src = ori || lw || sw || lui ? `ALU_SRC_EXT : `ALU_SRC_RT;
	assign alu_op =
		addu || lw || sw ? `ALU_OP_ADD :
		subu ? `ALU_OP_SUB :
		ori ? `ALU_OP_OR :
		beq ? `ALU_OP_EQ :
		lui ? `ALU_OP_SL16 : 0;
	assign mem_write = sw;
	assign jump_mode =
		beq ? `JUMP_MODE_OFFSET :
		jal ? `JUMP_MODE_ABS :
		jr ? `JUMP_MODE_INPUT :
		`JUMP_MODE_NEXT;
	assign ext_op = lw || sw ? `EXT_OP_SIGNED : `EXT_OP_ZERO;
endmodule

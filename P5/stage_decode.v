`include "def.v"

module stage_decode(
	input wire [31:0] pc,
	input wire [31:0] instr,
	input wire [31:0] grf_read_data0,
	input wire [31:0] grf_read_data1,
	output wire [4:0] grf_read_addr0,
	output wire [4:0] grf_read_addr1,
	output wire [1:0] grf_read_stage0,
	output wire [1:0] grf_read_stage1,
	output wire [4:0] grf_write_addr,
	output wire [1:0] grf_write_stage,
	output wire alu_src1,
	output wire [1:0] alu_op,
	output wire [31:0] ext_imm,
	output wire mem_write,
	output wire [31:0] next_pc
);
	wire [5:0] op = instr[31:26];
	wire [4:0] rs_addr = instr[25:21];
	wire [4:0] rt_addr = instr[20:16];
	wire [4:0] rd_addr = instr[15:11];
	wire [15:0] imm = instr[15:0];
	wire [5:0] func = instr[5:0];

	wire op_sp = op == 6'b000000;
	wire addu = op_sp && func == 6'b100001;
	wire subu = op_sp && func == 6'b100011;
	wire ori = op == 6'b001101;
	wire lw = op == 6'b100011;
	wire sw = op == 6'b101011;
	wire beq = op == 6'b000100;
	wire lui = op == 6'b001111;
	wire j = op == 6'b000010;
	wire jal = op == 6'b000011;
	wire jr = op_sp && func == 6'b001000;

	assign grf_read_addr0 = rs_addr;
	assign grf_read_addr1 = rt_addr;
	assign grf_read_stage0 =
		beq || jr ? `STAGE_DECODE :
		addu || subu || ori || lw || sw ? `STAGE_EXECUTE : `STAGE_MAX;
	assign grf_read_stage1 =
		beq ? `STAGE_DECODE :
		addu || subu ? `STAGE_EXECUTE :
		sw ? `STAGE_MEM : `STAGE_MAX;
	assign grf_write_addr =
		addu || subu ? rd_addr :
		ori || lw || lui ? rt_addr :
		jal ? 31 : 0;
	assign grf_write_stage =
		jal ? `STAGE_DECODE :
		addu || subu || ori || lui ? `STAGE_EXECUTE :
		lw ? `STAGE_MEM : 0;
	assign alu_src1 =
		ori || lw || sw || lui ? `ALU_SRC1_EXT : `ALU_SRC1_RT;
	assign alu_op =
		addu || lw || sw ? `ALU_OP_ADD :
		subu ? `ALU_OP_SUB :
		ori ? `ALU_OP_OR :
		lui ? `ALU_OP_SL16 : 0;
	assign ext_imm = lw || sw ? $signed({imm, 16'b0}) >>> 16 : $signed({16'b0, imm});
	assign mem_write = sw;

	assign next_pc =
		beq && grf_read_data0 == grf_read_data1 ? $signed(pc) + $signed({instr[15:0], 2'b0}) :
		j || jal ? pc[31:28] | {instr[25:0], 2'b0} :
		jr ? grf_read_data0 : pc + 4;
endmodule

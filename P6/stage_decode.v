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
	output wire alu_src0,
	output wire alu_src1,
	output wire [`ALU_OP_LEN - 1:0] alu_op,
	output wire [4:0] sa,
	output wire [31:0] ext_imm,
	output wire mem_write,
	output wire check_overflow,
	output wire [31:0] next_pc
);
	wire [5:0] op = instr[31:26];
	wire [4:0] rs_addr = instr[25:21];
	wire [4:0] rt_addr = instr[20:16];
	wire [4:0] rd_addr = instr[15:11];
	wire [15:0] imm = instr[15:0];
	wire [5:0] func = instr[5:0];

	wire op_sp = op == 6'b000000;
	wire add = op_sp && func == 6'b100000;
	wire addi = op == 6'b001000;
	wire addu = op_sp && func == 6'b100001;
	wire addiu = op == 6'b001001;
	wire sub = op_sp && func == 6'b100010;
	wire subu = op_sp && func == 6'b100011;
	wire sll = op_sp && func == 6'b000000;
	wire sllv = op_sp && func == 6'b000100;
	wire srlv = op_sp && func == 6'b000110;
	wire srl = op_sp && func == 6'b000010;
	wire sra = op_sp && func == 6'b000011;
	wire srav = op_sp && func == 6'b000111;
	wire _and = op_sp && func == 6'b100100;
	wire andi = op == 6'b001100;
	wire _or = op_sp && func == 6'b100101;
	wire ori = op == 6'b001101;
	wire _xor = op_sp && func == 6'b100110;
	wire xori = op == 6'b001110;
	wire _nor = op_sp && func == 6'b100111;
	wire lw = op == 6'b100011;
	wire sw = op == 6'b101011;
	wire beq = op == 6'b000100;
	wire lui = op == 6'b001111;
	wire j = op == 6'b000010;
	wire jal = op == 6'b000011;
	wire jr = op_sp && func == 6'b001000;
	wire jalr = op_sp && func == 6'b001001;

	assign grf_read_addr0 = rs_addr;
	assign grf_read_addr1 = rt_addr;
	assign grf_read_stage0 =
		beq || jr || jalr ? `STAGE_DECODE :
		add || addi || addu || addiu || sub || subu || sllv || srlv || srav || _and || andi || _or || ori || _xor || xori || _nor || lw || sw ? `STAGE_EXECUTE : `STAGE_MAX;
	assign grf_read_stage1 =
		beq ? `STAGE_DECODE :
		add || addu || sub || subu || sll || sllv || srl || srlv || sra || srav || _and || _or || _xor || _nor ? `STAGE_EXECUTE :
		sw ? `STAGE_MEM : `STAGE_MAX;
	assign grf_write_addr =
		add || addu || sub || subu || sll || sllv || srl || srlv || sra || srav || _and || _or|| _xor || _nor || jalr ? rd_addr :
		addi || addiu || andi || ori || xori || lw || lui ? rt_addr :
		jal ? 31 : 0;
	assign grf_write_stage =
		jal || jalr ? `STAGE_DECODE :
		add || addi || addu || addiu || sub || subu || sll || sllv || srl || srlv || sra || srav || _and || andi || _or || ori || _xor || xori || _nor || lui ? `STAGE_EXECUTE :
		lw ? `STAGE_MEM : 0;
	assign alu_src0 =
		lui || sll || srl || sra ? `ALU_SRC0_SA : `ALU_SRC0_RS;
	assign alu_src1 =
		addi || addiu || andi || ori || xori || lw || sw || lui ? `ALU_SRC1_EXT : `ALU_SRC1_RT;
	assign alu_op =
		add || addi || addu || addiu || lw || sw ? `ALU_OP_ADD :
		sub || subu ? `ALU_OP_SUB :
		lui || sll || sllv ? `ALU_OP_SLL :
		srl || srlv ? `ALU_OP_SRL :
		sra || srav ? `ALU_OP_SRA :
		_and || andi ? `ALU_OP_AND :
		_or || ori ? `ALU_OP_OR :
		_xor || xori ? `ALU_OP_XOR :
		_nor ? `ALU_OP_NOR : 0;
	assign sa = lui ? 16 : instr[10:6];
	assign ext_imm = addi || lw || sw ? {{16{imm[15]}}, imm} : {16'b0, imm};
	assign mem_write = sw;
	assign check_overflow = add || addi || sub;

	wire [31:0] branch_target = $signed(pc) + $signed({instr[15:0], 2'b0});
	assign next_pc =
		beq && grf_read_data0 == grf_read_data1 ? branch_target :
		j || jal ? pc[31:28] | {instr[25:0], 2'b0} :
		jr || jalr ? grf_read_data0 : pc + 4;
endmodule

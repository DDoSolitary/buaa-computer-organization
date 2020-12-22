`include "def.v"

module stage_decode(
	input wire [31:0] pc,
	input wire [31:0] instr,
	input wire [31:0] epc,
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
	output wire [`MEM_TYPE_LEN - 1:0] mem_type,
	output wire [`MEM_MODE_LEN - 1:0] mem_mode,
	output wire [`REG_EXT_LEN - 1:0] ext_type,
	output wire check_overflow,
	output wire [`DS_OP_LEN - 1:0] ds_op,
	output wire [31:0] next_pc,
	output wire [`CP0_OP_LEN - 1:0] cp0_op,
	output wire [4:0] cp0_addr,
	output wire [`EXC_CODE_LEN - 1:0] exc
);
	wire [5:0] op = instr[31:26];
	wire [4:0] rs_addr = instr[25:21];
	wire [4:0] rt_addr = instr[20:16];
	wire [4:0] rd_addr = instr[15:11];
	wire [15:0] imm = instr[15:0];
	wire [5:0] func = instr[5:0];

	wire op_sp = op == 6'b000000;
	wire op_regimm = op == 6'b000001;
	wire op_cp0 = op == 6'b010000;
	wire nop = instr == 0;
	wire add = op_sp && func == 6'b100000;
	wire addi = op == 6'b001000;
	wire addu = op_sp && func == 6'b100001;
	wire addiu = op == 6'b001001;
	wire sub = op_sp && func == 6'b100010;
	wire subu = op_sp && func == 6'b100011;
	wire sll = op_sp && func == 6'b000000;
	wire sllv = op_sp && func == 6'b000100;
	wire srl = op_sp && func == 6'b000010;
	wire srlv = op_sp && func == 6'b000110;
	wire sra = op_sp && func == 6'b000011;
	wire srav = op_sp && func == 6'b000111;
	wire slt = op_sp && func == 6'b101010;
	wire slti = op == 6'b001010;
	wire sltu = op_sp && func == 6'b101011;
	wire sltiu = op == 6'b001011;
	wire _and = op_sp && func == 6'b100100;
	wire andi = op == 6'b001100;
	wire _or = op_sp && func == 6'b100101;
	wire ori = op == 6'b001101;
	wire _xor = op_sp && func == 6'b100110;
	wire xori = op == 6'b001110;
	wire _nor = op_sp && func == 6'b100111;
	wire lb = op == 6'b100000;
	wire lbu = op == 6'b100100;
	wire lh = op == 6'b100001;
	wire lhu = op == 6'b100101;
	wire lw = op == 6'b100011;
	wire sb = op == 6'b101000;
	wire sh = op == 6'b101001;
	wire sw = op == 6'b101011;
	wire beq = op == 6'b000100;
	wire bne = op == 6'b000101;
	wire blez = op == 6'b000110;
	wire bltz = op_regimm && rt_addr == 5'b00000;
	wire bgez = op_regimm && rt_addr == 5'b00001;
	wire bgtz = op == 6'b000111;
	wire lui = op == 6'b001111;
	wire j = op == 6'b000010;
	wire jal = op == 6'b000011;
	wire jr = op_sp && func == 6'b001000;
	wire jalr = op_sp && func == 6'b001001;
	wire mult = op_sp && func == 6'b011000;
	wire multu = op_sp && func == 6'b011001;
	wire div = op_sp && func == 6'b011010;
	wire divu = op_sp && func == 6'b011011;
	wire mflo = op_sp && func == 6'b010010;
	wire mfhi = op_sp && func == 6'b010000;
	wire mtlo = op_sp && func == 6'b010011;
	wire mthi = op_sp && func == 6'b010001;
	wire mfc0 = op_cp0 && rs_addr == 6'b00000;
	wire mtc0 = op_cp0 && rs_addr == 6'b00100;
	wire eret = op_cp0 && instr[25];

	assign grf_read_addr0 = rs_addr;
	assign grf_read_addr1 = rt_addr;
	assign grf_read_stage0 =
			beq || bne || blez || bltz || bgez || bgtz || jr || jalr
		? `STAGE_DECODE :
			add || addi || addu || addiu || sub || subu ||
			sllv || srlv || srav ||
			slt || slti || sltu || sltiu ||
			_and || andi || _or || ori || _xor || xori || _nor ||
			lb || lbu || lh || lhu || lw || sb || sh || sw ||
			mult || multu || div || divu || mtlo || mthi
		? `STAGE_EXECUTE : `STAGE_MAX;
	assign grf_read_stage1 =
			beq || bne ?
		`STAGE_DECODE :
			add || addu || sub || subu ||
			sll || sllv || srl || srlv || sra || srav ||
			slt || sltu ||
			_and || _or || _xor || _nor ||
			mult || multu || div || divu
		? `STAGE_EXECUTE :
			sb || sh || sw ||
			mtc0
		? `STAGE_MEM : `STAGE_MAX;
	assign grf_write_addr =
			add || addu || sub || subu ||
			sll || sllv || srl || srlv || sra || srav ||
			slt || sltu ||
			_and || _or|| _xor || _nor ||
			jalr ||
			mflo || mfhi
		? rd_addr :
			addi || addiu ||
			lui ||
			slti || sltiu ||
			andi || ori || xori ||
			lb || lbu || lh || lhu || lw ||
			mfc0
		? rt_addr :
			jal
		? 31 : 0;
	assign grf_write_stage =
			jal || jalr
		? `STAGE_DECODE :
			add || addi || addu || addiu || sub || subu ||
			sll || sllv || srl || srlv || sra || srav || lui ||
			slt || slti || sltu || sltiu ||
			_and || andi || _or || ori || _xor || xori || _nor ||
			mflo || mfhi
		? `STAGE_EXECUTE :
			lb || lbu || lh || lhu || lw ||
			mfc0
		? `STAGE_MEM : 0;
	assign alu_src0 =
		lui || sll || srl || sra ? `ALU_SRC0_SA : `ALU_SRC0_RS;
	assign alu_src1 =
			addi || addiu ||
			lui ||
			slti || sltiu ||
			andi || ori || xori ||
			lb || lbu || lh || lhu || lw || sb || sh || sw
		? `ALU_SRC1_EXT : `ALU_SRC1_RT;
	assign alu_op =
		add || addi || addu || addiu || lb || lbu || lh || lhu || lw || sb || sh || sw ? `ALU_OP_ADD :
		sub || subu ? `ALU_OP_SUB :
		lui || sll || sllv ? `ALU_OP_SLL :
		srl || srlv ? `ALU_OP_SRL :
		sra || srav ? `ALU_OP_SRA :
		_and || andi ? `ALU_OP_AND :
		_or || ori ? `ALU_OP_OR :
		_xor || xori ? `ALU_OP_XOR :
		_nor ? `ALU_OP_NOR :
		slt || slti ? `ALU_OP_SLT :
		sltu || sltiu ? `ALU_OP_SLTU :
		mult ? `ALU_OP_MULT :
		multu ? `ALU_OP_MULTU :
		div ? `ALU_OP_DIV :
		divu ? `ALU_OP_DIVU :
		mflo ? `ALU_OP_MFLO :
		mfhi ? `ALU_OP_MFHI :
		mtlo ? `ALU_OP_MTLO :
		mthi ? `ALU_OP_MTHI : 0;
	assign sa = lui ? 16 : instr[10:6];
	assign ext_imm = addi || addiu || slti || sltiu || lb || lbu || lh || lhu || lw || sb || sh || sw
		? {{16{imm[15]}}, imm} : {16'b0, imm};
	assign mem_type =
		lb || lbu || sb ? `MEM_TYPE_BYTE :
		lh || lhu || sh ? `MEM_TYPE_HALF :
		lw || sw ? `MEM_TYPE_WORD : 0;
	assign mem_mode =
		lb || lbu || lh || lhu || lw ? `MEM_MODE_READ :
		sb || sh || sw ? `MEM_MODE_WRITE : `MEM_MODE_NONE;
	assign ext_type =
		lb ? `REG_EXT_BYTE :
		lbu ? `REG_EXT_BYTE_U :
		lh ? `REG_EXT_HALF :
		lhu ? `REG_EXT_HALF_U : `REG_EXT_NONE;
	assign check_overflow = add || addi || sub;
	assign ds_op =
		beq || bne || blez || bltz || bgez || bgtz || j || jal || jr || jalr ? `DS_OP_SET :
		eret ? `DS_OP_CLEAR : `DS_OP_NONE;

	wire [31:0] branch_target = $signed(pc) + $signed({instr[15:0], 2'b0});
	wire should_branch =
		beq && grf_read_data0 == grf_read_data1 ||
		bne && grf_read_data0 != grf_read_data1 ||
		blez && $signed(grf_read_data0) <= 0 ||
		bltz && $signed(grf_read_data0) < 0 ||
		bgez && $signed(grf_read_data0) >= 0 ||
		bgtz && $signed(grf_read_data0) > 0;
	assign next_pc =
		should_branch ? branch_target :
		j || jal ? pc[31:28] | {instr[25:0], 2'b0} :
		jr || jalr ? grf_read_data0 :
		eret ? epc : pc + 4;

	assign cp0_op =
		mfc0 ? `CP0_OP_MFC0 :
		mtc0 ? `CP0_OP_MTC0 :
		eret ? `CP0_OP_ERET : `CP0_OP_NONE;
	assign cp0_addr = rd_addr;

	assign exc =
			nop || add || addi || addu || addiu || sub || subu || sll || sllv || srl || srlv || sra || srav || slt ||
			slti || sltu || sltiu || _and || andi || _or || ori || _xor || xori || _nor || lb || lbu || lh || lhu ||
			lw || sb || sh || sw || beq || bne || blez || bltz || bgez || bgtz || lui || j || jal || jr || jalr ||
			mult || multu || div || divu || mflo || mfhi || mtlo || mthi || mfc0 || mtc0 || eret
		? 0 : `EXC_CODE_RI;
endmodule

`include "def.v"

module mips(
	input wire clk,
	input wire reset,
	input wire interrupt,
	output wire [31:0] addr
);
	wire [31:0] f_pc, f_instr, f_next_pc;
	wire [`EXC_CODE_LEN - 1:0] f_exc;

	wire [4:0] d_read_addr0, d_read_addr1, d_write_addr;
	wire [31:0] grf_read_data0, grf_read_data1, d_read_data0, d_read_data1, d_ext_imm, d_next_pc;
	wire [1:0] d_read_stage0, d_read_stage1, d_write_stage;
	wire [`ALU_OP_LEN - 1:0] d_alu_op;
	wire d_alu_src0, d_alu_src1, d_check_overflow;
	wire [4:0] d_sa;
	wire [`MEM_TYPE_LEN - 1:0] d_mem_type;
	wire [`MEM_MODE_LEN - 1:0] d_mem_mode;
	wire [`REG_EXT_LEN - 1:0] d_ext_type;
	wire [`DS_OP_LEN - 1:0] d_ds_op;
	wire [`CP0_OP_LEN - 1:0] d_cp0_op;
	wire [4:0] d_cp0_addr;
	wire [`EXC_CODE_LEN - 1:0] d_exc;

	wire [31:0] e_read_data0, e_read_data1, e_alu_result, e_write_data;
	wire e_overflowed, e_mem_unaligned, e_alu_busy;
	wire [`EXC_CODE_LEN - 1:0] e_exc;

	wire [31:0] m_read_data, m_mem_read_data, m_write_data;
	wire [`EXC_CODE_LEN - 1:0] m_exc;

	wire [31:0] w_write_data;

	wire [`MEM_MODE_LEN - 1:0] br_mode;
	wire [31:0] br_dev_addr, timer0_read_data, timer1_read_data, br_read_data;
	wire timer0_write_enable, timer1_write_enable, timer0_irq, timer1_irq;
	wire [`EXC_CODE_LEN - 1:0] br_exc;

	wire cp0_bd;
	wire [`EXC_CODE_LEN - 1:0] cp0_exc;
	wire [`HW_INT_LEN - 1:0] cp0_hw_int;
	wire cp0_int_req;
	wire [31:0] cp0_epc, cp0_read_data;

	reg [`STAGE_STAT_LEN - 1:0] fd_stage_stat;
	reg [31:0] fd_pc, fd_instr;
	reg [`EXC_CODE_LEN - 1:0] fd_exc;

	reg [`STAGE_STAT_LEN - 1:0] de_stage_stat;
	reg [31:0] de_pc;
	reg [4:0] de_read_addr0, de_read_addr1, de_write_addr;
	reg [31:0] de_read_data0, de_read_data1, de_write_data, de_ext_imm;
	reg [1:0] de_write_stage;
	reg [`ALU_OP_LEN - 1:0] de_alu_op;
	reg de_alu_src0, de_alu_src1, de_check_overflow;
	reg [4:0] de_sa;
	reg [`MEM_TYPE_LEN - 1:0] de_mem_type;
	reg [`MEM_MODE_LEN - 1:0] de_mem_mode;
	reg [`REG_EXT_LEN - 1:0] de_ext_type;
	reg [`CP0_OP_LEN - 1:0] de_cp0_op;
	reg [4:0] de_cp0_addr;
	reg [`EXC_CODE_LEN - 1:0] de_exc;

	reg [`STAGE_STAT_LEN - 1:0] em_stage_stat;
	reg [31:0] em_pc;
	reg [4:0] em_read_addr, em_write_addr;
	reg [31:0] em_read_data, em_write_data, em_alu_result;
	reg [1:0] em_write_stage;
	reg [`MEM_TYPE_LEN - 1:0] em_mem_type;
	reg [`MEM_MODE_LEN - 1:0] em_mem_mode;
	reg [`REG_EXT_LEN - 1:0] em_ext_type;
	reg [`CP0_OP_LEN - 1:0] em_cp0_op;
	reg [4:0] em_cp0_addr;
	reg [`EXC_CODE_LEN - 1:0] em_exc;

	reg [31:0] mw_pc;
	reg [4:0] mw_write_addr;
	reg [31:0] mw_write_data;
	reg [`REG_EXT_LEN - 1:0] mw_ext_type;

	assign addr =
		em_stage_stat != `STAGE_STAT_EMPTY ? em_pc :
		de_stage_stat != `STAGE_STAT_EMPTY ? de_pc :
		fd_stage_stat != `STAGE_STAT_EMPTY ? fd_pc : f_pc;

	assign e_write_data = de_write_stage == `STAGE_EXECUTE ? e_alu_result : de_write_data;
	assign m_write_data =
		em_cp0_op == `CP0_OP_MFC0 ? cp0_read_data :
		em_write_stage == `STAGE_MEM ? m_mem_read_data : em_write_data;

	assign d_read_data0 =
		d_read_addr0 == 0 ? 0 :
		d_read_addr0 == de_write_addr && de_write_stage <= `STAGE_DECODE ? de_write_data :
		d_read_addr0 == em_write_addr && em_write_stage <= `STAGE_EXECUTE ? em_write_data : grf_read_data0;
	assign d_read_data1 =
		d_read_addr1 == 0 ? 0 :
		d_read_addr1 == de_write_addr && de_write_stage <= `STAGE_DECODE ? de_write_data :
		d_read_addr1 == em_write_addr && em_write_stage <= `STAGE_EXECUTE ? em_write_data : grf_read_data1;
	assign e_read_data0 =
		de_read_addr0 == 0 ? 0 :
		de_read_addr0 == em_write_addr && em_write_stage <= `STAGE_EXECUTE ? em_write_data :
		de_read_addr0 == mw_write_addr ? w_write_data : de_read_data0;
	assign e_read_data1 =
		de_read_addr1 == 0 ? 0 :
		de_read_addr1 == em_write_addr && em_write_stage <= `STAGE_EXECUTE ? em_write_data :
		de_read_addr1 == mw_write_addr ? w_write_data : de_read_data1;
	assign m_read_data =
		em_read_addr == 0 ? 0 :
		em_read_addr == mw_write_addr ? w_write_data : em_read_data;

	wire stall_de = de_write_addr != 0 &&
		((d_read_addr0 == de_write_addr && de_write_stage > d_read_stage0) ||
		(d_read_addr1 == de_write_addr && de_write_stage > d_read_stage1));
	wire stall_em = em_write_addr != 0 &&
		((d_read_addr0 == em_write_addr && em_write_stage - 1 > d_read_stage0) ||
		(d_read_addr1 == em_write_addr && em_write_stage - 1 > d_read_stage1));
	wire stall_alu = d_alu_op >= `ALU_OP_STALL_MIN && d_alu_op <= `ALU_OP_STALL_MAX && e_alu_busy;
	wire stall_epc = d_cp0_op == `CP0_OP_ERET && de_cp0_op == `CP0_OP_MTC0 && de_cp0_addr == `CP0_ADDR_EPC;
	wire stall = stall_de || stall_em || stall_alu || stall_epc;

	assign cp0_bd = em_stage_stat == `STAGE_STAT_DS;
	assign cp0_exc = em_exc ? em_exc : m_exc;
	assign cp0_hw_int = {3'b0, interrupt, timer1_irq, timer0_irq};

	assign f_next_pc =
		cp0_int_req ? stage_fetch.ADDR_HANDLER :
		stall ? f_pc : d_next_pc;

	stage_fetch stage_fetch(
		.clk(clk), .reset(reset),
		.next_pc(f_next_pc),
		.pc(f_pc), .instr(f_instr),
		.exc(f_exc)
	);

	grf grf(
		.clk(clk), .reset(reset), .pc(mw_pc),
		.read_addr0(d_read_addr0), .read_addr1(d_read_addr1),
		.write_addr(mw_write_addr), .write_data(w_write_data),
		.read_data0(grf_read_data0), .read_data1(grf_read_data1)
	);

	stage_decode stage_decode(
		.pc(f_pc), .instr(fd_instr),
		.epc(cp0_epc),
		.grf_read_data0(d_read_data0), .grf_read_data1(d_read_data1),
		.grf_read_addr0(d_read_addr0), .grf_read_addr1(d_read_addr1),
		.grf_read_stage0(d_read_stage0), .grf_read_stage1(d_read_stage1),
		.grf_write_addr(d_write_addr), .grf_write_stage(d_write_stage),
		.alu_src0(d_alu_src0), .alu_src1(d_alu_src1), .alu_op(d_alu_op),
		.sa(d_sa), .ext_imm(d_ext_imm),
		.mem_type(d_mem_type), .mem_mode(d_mem_mode), .ext_type(d_ext_type),
		.check_overflow(d_check_overflow),
		.ds_op(d_ds_op),
		.next_pc(d_next_pc),
		.cp0_op(d_cp0_op), .cp0_addr(d_cp0_addr),
		.exc(d_exc)
	);

	stage_execute stage_execute(
		.clk(clk), .reset(reset),
		.grf_in0(e_read_data0), .grf_in1(e_read_data1),
		.alu_src0(de_alu_src0), .alu_src1(de_alu_src1), .alu_op(de_alu_op),
		.sa(de_sa), .ext_imm(de_ext_imm),
		.check_overflow(de_check_overflow),
		.int_req(cp0_int_req),
		.alu_result(e_alu_result),
		.alu_busy(e_alu_busy),
		.exc(e_exc)
	);

	stage_mem stage_mem(
		.clk(clk), .reset(reset), .pc(em_pc),
		.addr(em_alu_result),
		.write_data(m_read_data),
		.type(em_mem_type), .mode(em_mem_mode),
		.int_req(cp0_int_req),
		.br_read_data(br_read_data), .br_exc(br_exc), .br_mode(br_mode),
		.read_data(m_mem_read_data),
		.exc(m_exc)
	);

	stage_write stage_write(
		.in(mw_write_data),
		.ext_type(mw_ext_type),
		.out(w_write_data)
	);

	cp0 cp0(
		.clk(clk), .reset(reset),
		.addr(em_cp0_addr), .write_data(em_read_data),
		.bd(cp0_bd), .epc_in(addr), .exc(cp0_exc), .hw_int(cp0_hw_int), .op(em_cp0_op),
		.int_req(cp0_int_req), .epc_out(cp0_epc), .read_data(cp0_read_data)
	);

	bridge bridge(
		.vaddr(em_alu_result),
		.mode(br_mode),
		.int_req(cp0_int_req),
		.dev0_read_data(timer0_read_data), .dev1_read_data(timer1_read_data),
		.dev_addr(br_dev_addr),
		.dev0_write_enable(timer0_write_enable), .dev1_write_enable(timer1_write_enable),
		.read_data(br_read_data), .exc(br_exc)
	);

	TC timer0(
		.clk(clk), .reset(reset),
		.Addr(br_dev_addr[31:2]),
		.WE(timer0_write_enable),
		.Din(m_read_data),
		.Dout(br_read_data),
		.IRQ(timer0_irq)
	);

	TC timer1(
		.clk(clk), .reset(reset),
		.Addr(br_dev_addr[31:2]),
		.WE(timer1_write_enable),
		.Din(m_read_data),
		.Dout(br_read_data),
		.IRQ(timer1_irq)
	);

	always @(posedge clk)
		if (reset) begin
			fd_stage_stat <= 0;
			fd_pc <= 0;
			fd_instr <= 0;
			fd_exc <= 0;
			de_stage_stat <= 0;
			de_pc <= 0;
			de_read_addr0 <= 0;
			de_read_addr1 <= 0;
			de_read_data0 <= 0;
			de_read_data1 <= 0;
			de_write_addr <= 0;
			de_write_data <= 0;
			de_write_stage <= 0;
			de_alu_src0 <= 0;
			de_alu_src1 <= 0;
			de_alu_op <= 0;
			de_sa <= 0;
			de_ext_imm <= 0;
			de_mem_type <= 0;
			de_mem_mode <= 0;
			de_ext_type <= 0;
			de_check_overflow <= 0;
			de_cp0_op <= 0;
			de_cp0_addr <= 0;
			de_exc <= 0;
			em_stage_stat <= 0;
			em_pc <= 0;
			em_read_addr <= 0;
			em_read_data <= 0;
			em_write_addr <= 0;
			em_write_data <= 0;
			em_write_stage <= 0;
			em_mem_type <= 0;
			em_mem_mode <= 0;
			em_ext_type <= 0;
			em_alu_result <= 0;
			em_cp0_op <= 0;
			em_cp0_addr <= 0;
			em_exc <= 0;
			mw_pc <= 0;
			mw_write_addr <= 0;
			mw_write_data <= 0;
			mw_ext_type <= 0;
		end else begin
			fd_stage_stat <=
				cp0_int_req ? `STAGE_STAT_EMPTY :
				stall ? fd_stage_stat :
				d_ds_op == `DS_OP_CLEAR ? `STAGE_STAT_EMPTY :
				d_ds_op == `DS_OP_NONE ? `STAGE_STAT_NORMAL :
				d_ds_op == `DS_OP_SET ? `STAGE_STAT_DS : 0;
			fd_pc <= stall ? fd_pc : f_pc;
			fd_instr <=
				cp0_int_req ? 0 :
				stall ? fd_instr :
				d_ds_op == `DS_OP_CLEAR ? 0 : f_instr;
			fd_exc <= cp0_int_req ? 0 : stall ? fd_exc : f_exc;
			de_stage_stat <= cp0_int_req ? `STAGE_STAT_EMPTY : fd_stage_stat;
			de_pc <= fd_pc;
			de_read_addr0 <= d_read_addr0;
			de_read_addr1 <= d_read_addr1;
			de_read_data0 <= d_read_data0;
			de_read_data1 <= d_read_data1;
			de_write_addr <= stall || cp0_int_req ? 0 : d_write_addr;
			de_write_data <= f_pc + 4;
			de_write_stage <= d_write_stage;
			de_alu_src0 <= d_alu_src0;
			de_alu_src1 <= d_alu_src1;
			de_alu_op <= stall || cp0_int_req ? 0 : d_alu_op;
			de_sa <= d_sa;
			de_ext_imm <= d_ext_imm;
			de_mem_type <= d_mem_type;
			de_mem_mode <= stall || cp0_int_req ? `MEM_MODE_NONE : d_mem_mode;
			de_ext_type <= d_ext_type;
			de_check_overflow <= stall || cp0_int_req ? 0 : d_check_overflow;
			de_cp0_op <= stall || cp0_int_req ? `CP0_OP_NONE : d_cp0_op;
			de_cp0_addr <= d_cp0_addr;
			de_exc <= cp0_int_req ? 0 : fd_exc ? fd_exc : d_exc;
			em_stage_stat <= cp0_int_req ? `STAGE_STAT_EMPTY : de_stage_stat;
			em_pc <= de_pc;
			em_read_addr <= de_read_addr1;
			em_read_data <= e_read_data1;
			em_write_addr <= cp0_int_req ? 0 : de_write_addr;
			em_write_data <= e_write_data;
			em_write_stage <= de_write_stage;
			em_mem_type <= de_mem_type;
			em_mem_mode <= cp0_int_req ? `MEM_MODE_NONE : de_mem_mode;
			em_ext_type <= de_ext_type;
			em_alu_result <= e_alu_result;
			em_cp0_op <= cp0_int_req ? `CP0_OP_NONE : de_cp0_op;
			em_cp0_addr <= de_cp0_addr;
			em_exc <= cp0_int_req ? 0 : de_exc ? de_exc : e_exc;
			mw_pc <= em_pc;
			mw_write_addr <= cp0_int_req ? 0 : em_write_addr;
			mw_write_data <= m_write_data;
			mw_ext_type <= em_ext_type;
		end
endmodule

module mips_test();
	reg clk = 0, reset;
	reg [3:0] interrupt_count;
	reg irqs [2047:0];
	wire interrupt = interrupt_count > 0;
	wire [31:0] addr;
	wire [31:0] instr_id = (addr - 'h3000) / 4;

	always #5 clk = ~clk;

	mips uut(.clk(clk), .reset(reset), .interrupt(interrupt), .addr(addr));

	initial begin
		$dumpfile("P7.vcd");
		$dumpvars(0, mips_test);
		$readmemb("irqs.txt", irqs);
		reset = 1;
		interrupt_count = 0;
		#10;
		reset = 0;
		while (!(uut.cp0.op == `CP0_OP_ERET && (uut.cp0.epc < 'h3000 || uut.cp0.epc >= 'h5000))) begin
			if (interrupt_count > 0) interrupt_count = interrupt_count - 1;
			if (irqs[instr_id]) interrupt_count = 10;
			irqs[instr_id] = 0;
			#10;
		end
		#10;
		$finish();
	end
endmodule

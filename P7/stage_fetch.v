`include "def.v"

module stage_fetch #(
	parameter ADDR_MIN = 'h3000,
	parameter ADDR_MAX = 'h5000,
	parameter ADDR_HANDLER = 'h4180
) (
	input wire clk,
	input wire reset,
	input wire [31:0] next_pc,
	output reg [31:0] pc,
	output wire [31:0] instr,
	output wire [`EXC_CODE_LEN - 1:0] exc
);
	localparam WORD_ADDR_MIN = ADDR_MIN >> 2;
	localparam WORD_ADDR_MAX = ADDR_MAX >> 2;
	reg [31:0] mem [WORD_ADDR_MAX - 1:WORD_ADDR_MIN];
	wire [31:0] data = mem[pc[31:2]];

	assign exc = pc < ADDR_MIN || pc >= ADDR_MAX || pc[1:0] != 0 ? `EXC_CODE_ADEL : 0;
	assign instr = exc || ^data === 1'bx ? 0 : data;

	always @(posedge clk) begin
		if (reset) begin
			pc <= ADDR_MIN;
			$readmemh("code.txt", mem);
			$readmemh("code_handler.txt", mem, ADDR_HANDLER >> 2, WORD_ADDR_MAX - 1);
		end else pc <= next_pc;
	end
endmodule

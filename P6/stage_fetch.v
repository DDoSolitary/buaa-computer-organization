`include "def.v"

module stage_fetch #(parameter ADDR_WIDTH = 14, ADDR_OFFSET = 'h3000) (
	input wire clk,
	input wire reset,
	input wire [31:0] next_pc,
	output reg [31:0] pc,
	output wire [31:0] instr
);
	reg [31:0] mem [(1 << (ADDR_WIDTH - 2)) - 1:0];
	reg halted;

	wire [31:0] pc_offseted = pc - ADDR_OFFSET;
	wire [31:0] data = mem[pc_offseted[ADDR_WIDTH - 1:2]];
	wire should_halt = halted || (pc_offseted & ~((1 << ADDR_WIDTH) - 1)) != 0 || ^data === 1'bx;
	assign instr = should_halt ? 0 : data;

	always @(posedge clk) begin
		if (reset) begin
			pc <= ADDR_OFFSET;
			halted <= 0;
			$readmemh("code.txt", mem);
		end else begin
			pc <= next_pc;
			halted <= should_halt;
		end
	end
endmodule

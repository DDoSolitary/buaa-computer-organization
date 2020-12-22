`include "def.v"

module stage_mem #(parameter ADDR_MIN = 0, parameter ADDR_MAX = 'h3000) (
	input wire clk,
	input wire reset,
	input wire [31:0] pc,
	input wire [31:0] addr,
	input wire [31:0] write_data,
	input wire [`MEM_TYPE_LEN - 1:0] type,
	input wire [`MEM_MODE_LEN - 1:0] mode,
	input wire int_req,
	input wire [31:0] br_read_data,
	input wire [`EXC_CODE_LEN - 1:0] br_exc,
	output wire [`MEM_MODE_LEN - 1:0] br_mode,
	output wire [31:0] read_data,
	output wire [`EXC_CODE_LEN - 1:0] exc
);
	localparam WORD_ADDR_MIN = ADDR_MIN >> 2;
	localparam WORD_ADDR_MAX = ADDR_MAX >> 2;
	reg [31:0] mem [WORD_ADDR_MAX - 1:WORD_ADDR_MIN];

	wire [31:0] read_word = mem[addr[31:2]];
	wire invalid_addr =
		type == `MEM_TYPE_HALF && addr[0] != 0 ||
		type == `MEM_TYPE_WORD && addr[1:0] != 0;
	wire bridge_enable = !invalid_addr && (addr < ADDR_MIN || addr >= ADDR_MAX);

	assign br_mode = bridge_enable ? mode : `MEM_MODE_NONE;
	assign read_data =
		bridge_enable ? br_read_data :
		type == `MEM_TYPE_BYTE ? (
			addr[1:0] == 0 ? read_word[7:0] :
			addr[1:0] == 1 ? read_word[15:8] :
			addr[1:0] == 2 ? read_word[23:16] :
			addr[1:0] == 3 ? read_word[31:24] : 0) :
		type == `MEM_TYPE_HALF ? (
			addr[1] == 0 ? read_word[15:0] :
			addr[1] == 1 ? read_word[31:16] : 0) :
		type == `MEM_TYPE_WORD ? read_word : 0;
	assign exc =
		bridge_enable ? br_exc :
		mode == `MEM_MODE_READ && invalid_addr ? `EXC_CODE_ADEL :
		mode == `MEM_MODE_WRITE && invalid_addr ? `EXC_CODE_ADES : 0;

	wire [31:0] real_write_data =
		type == `MEM_TYPE_BYTE ? (
			addr[1:0] == 0 ? {read_word[31:8], write_data[7:0]} :
			addr[1:0] == 1 ? {read_word[31:16], write_data[7:0], read_word[7:0]} :
			addr[1:0] == 2 ? {read_word[31:24], write_data[7:0], read_word[15:0]} :
			addr[1:0] == 3 ? {write_data[7:0], read_word[23:0]} : 0) :
		type == `MEM_TYPE_HALF ? (
			addr[1] == 0 ? {read_word[31:16], write_data[15:0]} :
			addr[1] == 1 ? {write_data[15:0], read_word[15:0]} : 0) :
		type == `MEM_TYPE_WORD ? write_data : 0;

	integer i;
	always @(posedge clk)
		if (reset)
			for (i = WORD_ADDR_MIN; i < WORD_ADDR_MAX; i = i + 1) mem[i] <= 0;
		else if (mode == `MEM_MODE_WRITE && !bridge_enable && !int_req) begin
			$display("%d@%h: *%h <= %h", $time, pc, addr & ~'b11, real_write_data);
			mem[addr[31:2]] <= real_write_data;
		end
endmodule

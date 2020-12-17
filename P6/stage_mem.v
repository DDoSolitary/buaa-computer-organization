`include "def.v"

module stage_mem #(parameter ADDR_WIDTH = 12) (
	input wire clk,
	input wire reset,
	input wire write_enable,
	input wire [31:0] addr,
	input wire [31:0] write_data,
	input wire [`MEM_TYPE_LEN - 1:0] type,
	output wire [31:0] read_data
);
	localparam MEM_SIZE = 1 << (ADDR_WIDTH - 2);
	reg [31:0] mem [MEM_SIZE - 1:0];
	wire [31:0] read_word = mem[addr[ADDR_WIDTH - 1:2]];

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

	assign read_data =
		type == `MEM_TYPE_BYTE ? (
			addr[1:0] == 0 ? read_word[7:0] :
			addr[1:0] == 1 ? read_word[15:8] :
			addr[1:0] == 2 ? read_word[23:16] :
			addr[1:0] == 3 ? read_word[31:24] : 0) :
		type == `MEM_TYPE_HALF ? (
			addr[1] == 0 ? read_word[15:0] :
			addr[1] == 1 ? read_word[31:16] : 0) :
		type == `MEM_TYPE_WORD ? read_word : 0;

	integer i;
	always @(posedge clk)
		if (reset)
			for (i = 0; i < MEM_SIZE; i = i + 1) mem[i] <= 0;
		else if (write_enable)
			mem[addr[ADDR_WIDTH - 1:2]] <= real_write_data;
endmodule

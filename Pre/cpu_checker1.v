`define S_INVALID 0
`define S_TIME 1
`define S_PC 2
`define S_PRE_ADDR 3
`define S_REG_ADDR 4
`define S_MEM_ADDR 5
`define S_OP0 6
`define S_OP1 7
`define S_DATA 8
`define S_DONE 9

`define DEC_MINLEN 1
`define DEC_MAXLEN 4
`define HEX_LEN 8

`define START_CHAR "^"
`define END_CHAR "#"
`define TIME_END_CHAR "@"
`define PC_END_CHAR ":"
`define REG_START_CHAR "$"
`define MEM_START_CHAR "*"
`define OP0_CHAR "<"
`define OP1_CHAR "="
`define SPACE_CHAR " "

module cpu_checker(
	input clk,
	input reset,
	input [7:0] char,
	output [1:0] format_type
);
	function is_dec(input [7:0] char);
		is_dec = char >= "0" && char <= "9";
	endfunction

	function is_hex(input [7:0] char);
		is_hex = is_dec(char) || char >= "a" && char <= "f";
	endfunction

	reg [3:0] state = `S_INVALID;
	reg [3:0] num_len = 0;
	reg is_reg;

	assign format_type = state != `S_DONE ? 2'b00 : is_reg ? 2'b01 : 2'b10;

	always @(posedge clk) begin
		if (reset) begin
			state <= `S_INVALID;
			num_len <= 0;
		end else begin
			case (state)
			`S_INVALID: begin
				if (char == `START_CHAR) begin
					num_len <= 0;
					state <= `S_TIME;
				end else state <= `S_INVALID;
			end
			`S_TIME: begin
				if (is_dec(char)) begin
					if (num_len < `DEC_MAXLEN) num_len <= num_len + 1;
					else state <= `S_INVALID;
				end else if (char == `TIME_END_CHAR) begin
					if (num_len >= `DEC_MINLEN) begin
						num_len <= 0;
						state <= `S_PC;
					end else state <= `S_INVALID;
				end else state <= `S_INVALID;
			end
			`S_PC: begin
				if (is_hex(char)) begin
					if (num_len < `HEX_LEN) num_len <= num_len + 1;
					else state <= `S_INVALID;
				end else if (char == `PC_END_CHAR) begin
					if (num_len == `HEX_LEN) state <= `S_PRE_ADDR;
					else state <= `S_INVALID;
				end else state <= `S_INVALID;
			end
			`S_PRE_ADDR: begin
				if (char == `SPACE_CHAR) state <= `S_PRE_ADDR;
				else if (char == `REG_START_CHAR) begin
					num_len <= 0;
					is_reg <= 1;
					state <= `S_REG_ADDR;
				end else if (char == `MEM_START_CHAR) begin
					num_len <= 0;
					is_reg <= 0;
					state <= `S_MEM_ADDR;
				end else state <= `S_INVALID;
			end
			`S_REG_ADDR: begin
				if (is_dec(char)) begin
					if (num_len < `DEC_MAXLEN) num_len <= num_len + 1;
					else state <= `S_INVALID;
				end else begin
					if (num_len >= `DEC_MINLEN) begin
						if (char == `SPACE_CHAR) state <= `S_OP0;
						else if (char == `OP0_CHAR) state <= `S_OP1;
						else state <= `S_INVALID;
					end else state <= `S_INVALID;
				end
			end
			`S_MEM_ADDR: begin
				if (is_hex(char)) begin
					if (num_len < `HEX_LEN) num_len <= num_len + 1;
					else state <= `S_INVALID;
				end else begin
					if (num_len == `HEX_LEN) begin
						if (char == `SPACE_CHAR) state <= `S_OP0;
						else if (char == `OP0_CHAR) state <= `S_OP1;
						else state <= `S_INVALID;
					end else state <= `S_INVALID;
				end
			end
			`S_OP0: begin
				if (char == `SPACE_CHAR) state <= `S_OP0;
				else if (char == `OP0_CHAR) state <= `S_OP1;
				else state <= `S_INVALID;
			end
			`S_OP1: begin
				if (char == `OP1_CHAR) begin
					num_len <= 0;
					state <= `S_DATA;
				end else state <= `S_INVALID;
			end
			`S_DATA: begin
				if (char == `SPACE_CHAR) begin
					if (num_len == 0) state <= `S_DATA;
					else state <= `S_INVALID;
				end else if (is_hex(char)) begin
					if (num_len < `HEX_LEN) num_len <= num_len + 1;
					else state <= `S_INVALID;
				end else if (char == `END_CHAR) begin
					if (num_len == `HEX_LEN) state <= `S_DONE;
					else state <= `S_INVALID;
				end else state <= `S_INVALID;
			end
			`S_DONE: begin
				if (char == `START_CHAR) begin
					num_len <= 0;
					state <= `S_TIME;
				end else state <= `S_INVALID;
			end
			endcase
		end
	end
endmodule

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
`define MEM_START_CHAR 'd42
`define OP0_CHAR "<"
`define OP1_CHAR "="
`define SPACE_CHAR " "

`define E_TIME 1
`define E_PC 2
`define E_ADDR 4
`define E_GRF 8

module cpu_checker(
	input clk,
	input reset,
	input [7:0] char,
	input [15:0] freq,
	output [1:0] format_type,
	output [3:0] error_code
);
	function is_dec(input [7:0] char);
		is_dec = char >= "0" && char <= "9";
	endfunction

	function is_hex(input [7:0] char);
		is_hex = is_dec(char) || char >= "a" && char <= "f";
	endfunction

	function [31:0] input_dec(input [31:0] cur, input [7:0] char);
		input_dec = (cur << 3) + (cur << 1) + (char - "0");
	endfunction

	function [31:0] input_hex(input [31:0] cur, input [7:0] char);
		if (is_dec(char)) input_hex = (cur << 4) + (char - "0");
		else input_hex = (cur << 4) + (char - "a" + 10);
	endfunction

	reg [3:0] state = `S_INVALID;
	reg [3:0] num_len;
	reg [31:0] num;
	reg is_reg;
	reg [3:0] err;

	assign format_type = state != `S_DONE ? 0 : is_reg ? 1 : 2;
	assign error_code = state != `S_DONE ? 0 : err;

	always @(posedge clk) begin
		if (reset) begin
			state <= `S_INVALID;
		end else begin
			case (state)
			`S_INVALID: begin
				if (char == `START_CHAR) begin
					num_len <= 0;
					num <= 0;
					err <= 0;
					state <= `S_TIME;
				end else state <= `S_INVALID;
			end
			`S_TIME: begin
				if (is_dec(char)) begin
					if (num_len < `DEC_MAXLEN) begin
						num_len <= num_len + 1;
						num <= input_dec(num, char);
					end else state <= `S_INVALID;
				end else if (char == `TIME_END_CHAR) begin
					if (num_len >= `DEC_MINLEN) begin
						if (num & ((freq >> 1) - 1)) err <= err | `E_TIME;
						num_len <= 0;
						num <= 0;
						state <= `S_PC;
					end else state <= `S_INVALID;
				end else state <= `S_INVALID;
			end
			`S_PC: begin
				if (is_hex(char)) begin
					if (num_len < `HEX_LEN) begin
						num_len <= num_len + 1;
						num <= input_hex(num, char);
					end else state <= `S_INVALID;
				end else if (char == `PC_END_CHAR) begin
					if (num_len == `HEX_LEN) begin
						if (num < 'h3000 || num > 'h4fff || (num & 'b11)) err <= err | `E_PC;
						state <= `S_PRE_ADDR;
					end
					else state <= `S_INVALID;
				end else state <= `S_INVALID;
			end
			`S_PRE_ADDR: begin
				if (char == `SPACE_CHAR) state <= `S_PRE_ADDR;
				else if (char == `REG_START_CHAR) begin
					num_len <= 0;
					num <= 0;
					is_reg <= 1;
					state <= `S_REG_ADDR;
				end else if (char == `MEM_START_CHAR) begin
					num_len <= 0;
					num <= 0;
					is_reg <= 0;
					state <= `S_MEM_ADDR;
				end else state <= `S_INVALID;
			end
			`S_REG_ADDR: begin
				if (is_dec(char)) begin
					if (num_len < `DEC_MAXLEN) begin
						num_len <= num_len + 1;
						num <= input_dec(num, char);
					end else state <= `S_INVALID;
				end else begin
					if (num_len >= `DEC_MINLEN) begin
						if (num > 31) err <= err | `E_GRF;
						if (char == `SPACE_CHAR) state <= `S_OP0;
						else if (char == `OP0_CHAR) state <= `S_OP1;
						else state <= `S_INVALID;
					end else state <= `S_INVALID;
				end
			end
			`S_MEM_ADDR: begin
				if (is_hex(char)) begin
					if (num_len < `HEX_LEN) begin
						num_len <= num_len + 1;
						num <= input_hex(num, char);
					end else state <= `S_INVALID;
				end else begin
					if (num_len == `HEX_LEN) begin
						if (num > 'h2fff || (num & 'b11)) err <= err | `E_ADDR;
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
					num <= 0;
					err <= 0;
					state <= `S_TIME;
				end else state <= `S_INVALID;
			end
			endcase
		end
	end
endmodule

module cpu_checker_test;
	reg clk = 1;
	reg reset = 0;
	reg [7:0] char;
	wire [15:0] freq = 2;
	wire [1:0] format_type;
	wire [3:0] error_code;

	cpu_checker uut(clk, reset, char, freq, format_type, error_code);

	localparam INPUT_LEN = 34; 
	wire [(INPUT_LEN << 3) - 1 : 0] input_data = "^1024@000030fc: $2 <= 89abcdef#^64";

	always #5 clk = ~clk;

	integer i;
	initial begin
`ifdef DUMPFILE
		$dumpfile(`DUMPFILE);
		$dumpvars(0, cpu_checker_test);
`endif
		#10
		reset = 1;
		#10
		reset = 0;
		for (i = INPUT_LEN - 1; i >= 0; i = i - 1) begin
			char = input_data[i << 3 +: 8];
			#10;
		end
		#50;
		$finish();
	end
endmodule

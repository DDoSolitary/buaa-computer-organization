`include "def.v"

module stage_write(
	input wire [31:0] in,
	input wire [`REG_EXT_LEN - 1:0] ext_type,
	output wire [31:0] out
);
	assign out =
		ext_type == `REG_EXT_NONE ? in :
		ext_type == `REG_EXT_BYTE ? {{24{in[7]}}, in[7:0]} :
		ext_type == `REG_EXT_BYTE_U ? {24'b0, in[7:0]} :
		ext_type == `REG_EXT_HALF ? {{16{in[15]}}, in[15:0]} :
		ext_type == `REG_EXT_HALF_U ? {16'b0, in[15:0]} : 0;
endmodule

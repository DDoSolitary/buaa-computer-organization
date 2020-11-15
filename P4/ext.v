`include "constants.v"

module ext(
	input [15:0] in,
	input op,
	output reg [31:0] out
);
	always @*
		case (op)
			`EXT_OP_ZERO: out = {16'b0, in};
			`EXT_OP_SIGNED: out = $signed({in, 16'b0}) >>> 16;
			default: out = 0;
		endcase
endmodule

module ext_test(input start, output reg stop = 0);
	reg [15:0] in;
	reg op;
	wire [31:0] out;

	ext uut(in, op, out);

	always @(posedge start) begin
		$display("--- ext_test start ---");
		in = 16'hff42;
		op = `EXT_OP_ZERO;
		#1;
		$display("zero: %h", out);
		op = `EXT_OP_SIGNED;
		#1;
		$display("signed: %h", out);
		$display("--- ext_test stop ---\n");
		stop = 1;
	end
endmodule

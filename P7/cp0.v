`include "def.v"

`define STATUS_IM_HIGH 15
`define STATUS_EXL 1
`define STATUS_IE 0

`define CAUSE_BD 31
`define CAUSE_IP_HIGH 15
`define CAUSE_EXC_HIGH 6

module cp0(
	input wire clk,
	input wire reset,
	input wire [4:0] addr,
	input wire [31:0] write_data,
	input wire bd,
	input wire [31:0] epc_in,
	input wire [`EXC_CODE_LEN - 1:0] exc,
	input wire [`HW_INT_LEN - 1:0] hw_int,
	input wire [`CP0_OP_LEN - 1:0] op,
	output wire int_req,
	output wire [31:0] epc_out,
	output wire [31:0] read_data
);
	reg [31:0] status, cause, epc;
	wire [31:0] prid = 'hdeadbeaf;

	wire [`HW_INT_LEN - 1:0] masked_int = hw_int & status[`STATUS_IM_HIGH -: `HW_INT_LEN];
	wire hw_int_req = !status[`STATUS_EXL] && status[`STATUS_IE] && masked_int;
	wire [31:0] write_data_aligned = write_data & ~'b11;
	wire [31:0] epc_in_aligned = epc_in & ~'b11;

	assign int_req = exc || hw_int_req;
	assign epc_out = op == `CP0_OP_MTC0 && addr == `CP0_ADDR_EPC ? write_data_aligned : epc;
	assign read_data =
		addr == `CP0_ADDR_STATUS ? status :
		addr == `CP0_ADDR_CAUSE ? cause :
		addr == `CP0_ADDR_EPC ? epc :
		addr == `CP0_ADDR_PRID ? prid : 0;

	always @(posedge clk)
		if (reset) begin
			status <= 'b1000000000001;
			cause <= 0;
			epc <= 0;
		end else begin
			cause[`CAUSE_IP_HIGH -: `HW_INT_LEN] <= hw_int;
			if (op == `CP0_OP_MTC0) begin
				if (addr == `CP0_ADDR_STATUS) begin
					status[`STATUS_IE] <= write_data[`STATUS_IE];
					status[`STATUS_EXL] <= write_data[`STATUS_EXL];
					status[`STATUS_IM_HIGH -: `HW_INT_LEN] <= write_data[`STATUS_IM_HIGH -: `HW_INT_LEN];
				end else if (addr == `CP0_ADDR_EPC)
					epc <= write_data_aligned;
			end else if (op == `CP0_OP_ERET)
				status[`STATUS_EXL] <= 0;
			else if (int_req) begin
				status[`STATUS_EXL] <= 1;
				cause[`CAUSE_BD] <= bd;
				cause[`CAUSE_EXC_HIGH -: `EXC_CODE_LEN] <= hw_int_req ? `EXC_CODE_INT : exc;
				epc <= bd ? epc_in_aligned - 4 : epc_in_aligned;
			end
		end
endmodule

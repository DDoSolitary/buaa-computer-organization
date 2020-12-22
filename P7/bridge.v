`include "def.v"

module bridge #(
	parameter DEV0_OFFSET = 'h7f00,
	parameter DEV0_LEN = 12,
	parameter DEV0_RO_ADDR = 8,
	parameter DEV1_OFFSET = 'h7f10,
	parameter DEV1_LEN = 12,
	parameter DEV1_RO_ADDR = 8
) (
	input wire [31:0] vaddr,
	input wire [`MEM_MODE_LEN - 1:0] mode,
	input wire int_req,
	input wire [31:0] dev0_read_data,
	input wire [31:0] dev1_read_data,
	output wire [31:0] dev_addr,
	output wire dev0_write_enable,
	output wire dev1_write_enable,
	output wire [31:0] read_data,
	output wire [`EXC_CODE_LEN - 1:0] exc
);
	wire dev0_selected = vaddr >= DEV0_OFFSET && vaddr < DEV0_OFFSET + DEV0_LEN;
	wire dev1_selected = vaddr >= DEV1_OFFSET && vaddr < DEV1_OFFSET + DEV1_LEN;

	assign dev_addr =
		dev0_selected ? vaddr - DEV0_OFFSET :
		dev1_selected ? vaddr - DEV1_OFFSET : 0;
	assign dev0_write_enable = mode == `MEM_MODE_WRITE && !int_req && dev0_selected;
	assign dev1_write_enable = mode == `MEM_MODE_WRITE && !int_req && dev1_selected;
	assign read_data =
		dev0_selected ? dev0_read_data :
		dev1_selected ? dev1_read_data : 0;

	wire err =
		vaddr[1:0] != 0 ||
		!(dev0_selected || dev1_selected) ||
		mode == `MEM_MODE_WRITE &&
			(dev0_selected && dev_addr == DEV0_RO_ADDR ||
			dev1_selected && dev_addr == DEV1_RO_ADDR);
	assign exc = !err ? 0 :
		mode == `MEM_MODE_READ ? `EXC_CODE_ADEL :
		mode == `MEM_MODE_WRITE ? `EXC_CODE_ADES : 0;
endmodule

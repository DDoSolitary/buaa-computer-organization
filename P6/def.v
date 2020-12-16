`default_nettype none

`define STAGE_DECODE 0
`define STAGE_EXECUTE 1
`define STAGE_MEM 2
`define STAGE_MAX 3

`define ALU_SRC0_RS 0
`define ALU_SRC0_SA 1

`define ALU_SRC1_RT 0
`define ALU_SRC1_EXT 1

`define ALU_OP_LEN 4
`define ALU_OP_ADD 0
`define ALU_OP_SUB 1
`define ALU_OP_AND 2
`define ALU_OP_OR 3
`define ALU_OP_XOR 4
`define ALU_OP_NOR 5
`define ALU_OP_SLL 6
`define ALU_OP_SRL 7
`define ALU_OP_SRA 8
`define ALU_OP_SLT 9
`define ALU_OP_SLTU 10

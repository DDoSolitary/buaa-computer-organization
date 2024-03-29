`default_nettype none

`define STAGE_DECODE 0
`define STAGE_EXECUTE 1
`define STAGE_MEM 2
`define STAGE_MAX 3

`define ALU_SRC0_RS 0
`define ALU_SRC0_SA 1

`define ALU_SRC1_RT 0
`define ALU_SRC1_EXT 1

`define ALU_OP_LEN 5
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
`define ALU_OP_MULT 11
`define ALU_OP_MULTU 12
`define ALU_OP_DIV 13
`define ALU_OP_DIVU 14
`define ALU_OP_MFLO 15
`define ALU_OP_MFHI 16
`define ALU_OP_MTLO 17
`define ALU_OP_MTHI 18
`define ALU_OP_STALL_MIN `ALU_OP_MULT
`define ALU_OP_STALL_MAX `ALU_OP_MTHI
`define ALU_OP_BUSY_MIN `ALU_OP_MULT
`define ALU_OP_BUSY_MAX `ALU_OP_DIVU

`define MEM_TYPE_LEN 2
`define MEM_TYPE_BYTE 0
`define MEM_TYPE_HALF 1
`define MEM_TYPE_WORD 2

`define REG_EXT_LEN 3
`define REG_EXT_NONE 0
`define REG_EXT_BYTE 1
`define REG_EXT_BYTE_U 2
`define REG_EXT_HALF 3
`define REG_EXT_HALF_U 4

`timescale 1ns/1ps

package core_pkg;

    parameter int OP_W = 4;

    typedef enum logic [OP_W-1:0] {
        OP_ADD = 4'd0,
        OP_SUB = 4'd1,
        OP_AND = 4'd2,
        OP_OR  = 4'd3,
        OP_XOR = 4'd4,
        OP_MUL = 4'd5
    } opcode_t;

endpackage

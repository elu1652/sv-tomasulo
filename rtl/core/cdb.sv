`timescale 1ns/1ps

module cdb #(
    parameter int XLEN = 32,
    parameter int TAG_WIDTH = 3
) (
    // Result coming from one FU
    input logic fu_result_valid,
    input logic [TAG_WIDTH-1:0] fu_result_tag,
    input logic [XLEN-1:0] fu_result_value,

    // Broadcast result going to ROB + RS
    output logic cdb_valid,
    output logic [TAG_WIDTH-1:0] cdb_tag,
    output logic [XLEN-1:0] cdb_value
);

    always_comb begin
        cdb_valid = fu_result_valid;
        cdb_tag   = fu_result_tag;
        cdb_value = fu_result_value;
    end
endmodule

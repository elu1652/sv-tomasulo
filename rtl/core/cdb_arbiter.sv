`timescale 1ns/1ps

module cdb_arbiter #(
    parameter int XLEN  = 32,
    parameter int TAG_W = 2
) (
    // Source 0: ALU
    input  logic             src0_valid,
    input  logic [TAG_W-1:0] src0_tag,
    input  logic [XLEN-1:0]  src0_value,
    output logic             src0_ready,

    // Source 1: MUL
    input  logic             src1_valid,
    input  logic [TAG_W-1:0] src1_tag,
    input  logic [XLEN-1:0]  src1_value,
    output logic             src1_ready,

    // Selected CDB result
    output logic             cdb_valid,
    output logic [TAG_W-1:0] cdb_tag,
    output logic [XLEN-1:0]  cdb_value
);

    always_comb begin
        // Default: nobody is selected
        src0_ready = 1'b0;
        src1_ready = 1'b0;

        cdb_valid = 1'b0;
        cdb_tag   = '0;
        cdb_value = '0;

        // Fixed priority: source 0 wins whenever it is valid
        if (src0_valid) begin
            src0_ready = 1'b1;
            cdb_valid  = 1'b1;
            cdb_tag    = src0_tag;
            cdb_value  = src0_value;
        end else if (src1_valid) begin
            src1_ready = 1'b1;
            cdb_valid  = 1'b1;
            cdb_tag    = src1_tag;
            cdb_value  = src1_value;
        end
    end

endmodule

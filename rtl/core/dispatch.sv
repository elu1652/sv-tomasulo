`timescale 1ns/1ps

module dispatch #(
    parameter int XLEN       = 32,
    parameter int REG_ADDR_W = 3,
    parameter int TAG_W      = 2,
    parameter int OP_W       = 4
) (
    // Decoded instruction input
    input  logic                  dispatch_valid,
    output logic                  dispatch_ready,

    input  logic [OP_W-1:0]       dispatch_op,
    input  logic [REG_ADDR_W-1:0] dispatch_src1_reg,
    input  logic [REG_ADDR_W-1:0] dispatch_src2_reg,
    input  logic [REG_ADDR_W-1:0] dispatch_dest_reg,

    // Register-file lookup
    output logic [REG_ADDR_W-1:0] rf_raddr1,
    output logic [REG_ADDR_W-1:0] rf_raddr2,
    input  logic [XLEN-1:0]       rf_rdata1,
    input  logic [XLEN-1:0]       rf_rdata2,

    // Rename-table source lookup
    output logic [REG_ADDR_W-1:0] rename_src1_reg,
    input  logic                  rename_src1_pending,
    input  logic [TAG_W-1:0]      rename_src1_tag,

    output logic [REG_ADDR_W-1:0] rename_src2_reg,
    input  logic                  rename_src2_pending,
    input  logic [TAG_W-1:0]      rename_src2_tag,

    // ROB allocation
    output logic                  rob_alloc_valid,
    input  logic                  rob_alloc_ready,
    output logic [REG_ADDR_W-1:0] rob_alloc_dest_reg,
    input  logic [TAG_W-1:0]      rob_alloc_tag,

    // Rename-table destination update
    output logic                  rename_valid,
    output logic [REG_ADDR_W-1:0] rename_dest_reg,
    output logic [TAG_W-1:0]      rename_dest_tag,

    // Reservation-station dispatch
    output logic                  rs_dispatch_valid,
    input  logic                  rs_dispatch_ready,
    output logic [OP_W-1:0]       rs_dispatch_op,

    output logic                  rs_dispatch_src1_ready,
    output logic [XLEN-1:0]       rs_dispatch_src1_value,
    output logic [TAG_W-1:0]      rs_dispatch_src1_tag,

    output logic                  rs_dispatch_src2_ready,
    output logic [XLEN-1:0]       rs_dispatch_src2_value,
    output logic [TAG_W-1:0]      rs_dispatch_src2_tag,

    output logic [TAG_W-1:0]      rs_dispatch_dest_tag
);

    logic dispatch_fire;

    always_comb begin
        // The register file and rename table look up the same
        // architectural source registers.
        rf_raddr1 = dispatch_src1_reg;
        rf_raddr2 = dispatch_src2_reg;

        rename_src1_reg = dispatch_src1_reg;
        rename_src2_reg = dispatch_src2_reg;

        // Dispatch succeeds only if both the ROB and reservation
        // station can accept the instruction.
        dispatch_ready = rob_alloc_ready && rs_dispatch_ready;
        dispatch_fire  = dispatch_valid && dispatch_ready;

        // These three updates must happen together.
        rob_alloc_valid   = dispatch_fire;
        rename_valid      = dispatch_fire;
        rs_dispatch_valid = dispatch_fire;

        // The ROB stores the architectural destination register.
        rob_alloc_dest_reg = dispatch_dest_reg;

        // The allocated ROB tag becomes the newest producer of the
        // architectural destination register.
        rename_dest_reg = dispatch_dest_reg;
        rename_dest_tag = rob_alloc_tag;

        // The same ROB tag travels with the instruction through the RS
        // and functional unit.
        rs_dispatch_op       = dispatch_op;
        rs_dispatch_dest_tag = rob_alloc_tag;

        // Source operand 1 becomes either a waiting producer tag or a
        // ready committed register-file value.
        if (rename_src1_pending) begin
            rs_dispatch_src1_ready = 1'b0;
            rs_dispatch_src1_value = '0;
            rs_dispatch_src1_tag   = rename_src1_tag;
        end else begin
            rs_dispatch_src1_ready = 1'b1;
            rs_dispatch_src1_value = rf_rdata1;
            rs_dispatch_src1_tag   = '0;
        end

        // Source operand 2 is handled in the same way.
        if (rename_src2_pending) begin
            rs_dispatch_src2_ready = 1'b0;
            rs_dispatch_src2_value = '0;
            rs_dispatch_src2_tag   = rename_src2_tag;
        end else begin
            rs_dispatch_src2_ready = 1'b1;
            rs_dispatch_src2_value = rf_rdata2;
            rs_dispatch_src2_tag   = '0;
        end
    end

endmodule

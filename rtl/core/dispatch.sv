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

    // ALU reservation-station dispatch
    output logic                  alu_rs_dispatch_valid,
    input  logic                  alu_rs_dispatch_ready,
    output logic [OP_W-1:0]       alu_rs_dispatch_op,

    output logic                  alu_rs_dispatch_src1_ready,
    output logic [XLEN-1:0]       alu_rs_dispatch_src1_value,
    output logic [TAG_W-1:0]      alu_rs_dispatch_src1_tag,

    output logic                  alu_rs_dispatch_src2_ready,
    output logic [XLEN-1:0]       alu_rs_dispatch_src2_value,
    output logic [TAG_W-1:0]      alu_rs_dispatch_src2_tag,

    output logic [TAG_W-1:0]      alu_rs_dispatch_dest_tag,

    // Multiply reservation-station dispatch
    output logic                  mul_rs_dispatch_valid,
    input  logic                  mul_rs_dispatch_ready,
    output logic [OP_W-1:0]       mul_rs_dispatch_op,

    output logic                  mul_rs_dispatch_src1_ready,
    output logic [XLEN-1:0]       mul_rs_dispatch_src1_value,
    output logic [TAG_W-1:0]      mul_rs_dispatch_src1_tag,

    output logic                  mul_rs_dispatch_src2_ready,
    output logic [XLEN-1:0]       mul_rs_dispatch_src2_value,
    output logic [TAG_W-1:0]      mul_rs_dispatch_src2_tag,

    output logic [TAG_W-1:0]      mul_rs_dispatch_dest_tag
);

    import core_pkg::*;

    logic instruction_is_mul;
    logic selected_rs_ready;
    logic dispatch_fire;

    // Internal formatted source operands
    logic             formatted_src1_ready;
    logic [XLEN-1:0]  formatted_src1_value;
    logic [TAG_W-1:0] formatted_src1_tag;

    logic             formatted_src2_ready;
    logic [XLEN-1:0]  formatted_src2_value;
    logic [TAG_W-1:0] formatted_src2_tag;

    always_comb begin
        // ------------------------------------------------------------
        // Source-register lookups
        // ------------------------------------------------------------

        // The register file and rename table both look up the decoded
        // architectural source registers.
        rf_raddr1 = dispatch_src1_reg;
        rf_raddr2 = dispatch_src2_reg;

        rename_src1_reg = dispatch_src1_reg;
        rename_src2_reg = dispatch_src2_reg;

        // ------------------------------------------------------------
        // Operation classification
        // ------------------------------------------------------------

        instruction_is_mul = (dispatch_op == OP_MUL);

        // Only the selected reservation station needs to be ready.
        if (instruction_is_mul) begin
            selected_rs_ready = mul_rs_dispatch_ready;
        end else begin
            selected_rs_ready = alu_rs_dispatch_ready;
        end

        // ------------------------------------------------------------
        // Atomic dispatch handshake
        // ------------------------------------------------------------

        // Every instruction requires a ROB entry and space in its
        // selected reservation station.
        dispatch_ready = rob_alloc_ready && selected_rs_ready;
        dispatch_fire  = dispatch_valid && dispatch_ready;

        // Every successfully dispatched instruction allocates a ROB
        // entry and updates the rename table.
        rob_alloc_valid = dispatch_fire;
        rename_valid    = dispatch_fire;

        // Only one reservation station receives the instruction.
        alu_rs_dispatch_valid =
            dispatch_fire && !instruction_is_mul;

        mul_rs_dispatch_valid =
            dispatch_fire && instruction_is_mul;

        // ------------------------------------------------------------
        // ROB and rename-table destination information
        // ------------------------------------------------------------

        rob_alloc_dest_reg = dispatch_dest_reg;

        rename_dest_reg = dispatch_dest_reg;
        rename_dest_tag = rob_alloc_tag;

        // ------------------------------------------------------------
        // Format source operand 1
        // ------------------------------------------------------------

        if (rename_src1_pending) begin
            formatted_src1_ready = 1'b0;
            formatted_src1_value = '0;
            formatted_src1_tag   = rename_src1_tag;
        end else begin
            formatted_src1_ready = 1'b1;
            formatted_src1_value = rf_rdata1;
            formatted_src1_tag   = '0;
        end

        // ------------------------------------------------------------
        // Format source operand 2
        // ------------------------------------------------------------

        if (rename_src2_pending) begin
            formatted_src2_ready = 1'b0;
            formatted_src2_value = '0;
            formatted_src2_tag   = rename_src2_tag;
        end else begin
            formatted_src2_ready = 1'b1;
            formatted_src2_value = rf_rdata2;
            formatted_src2_tag   = '0;
        end

        // ------------------------------------------------------------
        // ALU reservation-station packet
        // ------------------------------------------------------------

        alu_rs_dispatch_op       = dispatch_op;
        alu_rs_dispatch_dest_tag = rob_alloc_tag;

        alu_rs_dispatch_src1_ready = formatted_src1_ready;
        alu_rs_dispatch_src1_value = formatted_src1_value;
        alu_rs_dispatch_src1_tag   = formatted_src1_tag;

        alu_rs_dispatch_src2_ready = formatted_src2_ready;
        alu_rs_dispatch_src2_value = formatted_src2_value;
        alu_rs_dispatch_src2_tag   = formatted_src2_tag;

        // ------------------------------------------------------------
        // Multiply reservation-station packet
        // ------------------------------------------------------------

        mul_rs_dispatch_op       = dispatch_op;
        mul_rs_dispatch_dest_tag = rob_alloc_tag;

        mul_rs_dispatch_src1_ready = formatted_src1_ready;
        mul_rs_dispatch_src1_value = formatted_src1_value;
        mul_rs_dispatch_src1_tag   = formatted_src1_tag;

        mul_rs_dispatch_src2_ready = formatted_src2_ready;
        mul_rs_dispatch_src2_value = formatted_src2_value;
        mul_rs_dispatch_src2_tag   = formatted_src2_tag;
    end

endmodule

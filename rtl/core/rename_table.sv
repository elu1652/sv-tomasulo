`timescale 1ns/1ps

module rename_table #(
    parameter int NUM_REGS   = 8,
    parameter int REG_ADDR_W = 3,
    parameter int TAG_W      = 3
) (
    input logic clk,
    input logic rst_n,

    // Source register lookup ports
    input  logic [REG_ADDR_W-1:0] src1_reg,
    output logic                  src1_pending,
    output logic [TAG_W-1:0]      src1_tag,

    input  logic [REG_ADDR_W-1:0] src2_reg,
    output logic                  src2_pending,
    output logic [TAG_W-1:0]      src2_tag,

    // Destination rename update from dispatch/issue
    input logic                  rename_valid,
    input logic [REG_ADDR_W-1:0] rename_dest_reg,
    input logic [TAG_W-1:0]      rename_dest_tag,

    // Commit clears old mappings, but only if the committing ROB tag
    // is still the current producer for that architectural register.
    input logic                  commit_valid,
    input logic [REG_ADDR_W-1:0] commit_dest_reg,
    input logic [TAG_W-1:0]      commit_tag
);

    logic             producer_valid [0:NUM_REGS-1];
    logic [TAG_W-1:0] producer_tag   [0:NUM_REGS-1];

    assign src1_pending = producer_valid[src1_reg];
    assign src1_tag     = producer_tag[src1_reg];

    assign src2_pending = producer_valid[src2_reg];
    assign src2_tag     = producer_tag[src2_reg];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_REGS; i++) begin
                producer_valid[i] <= 1'b0;
                producer_tag[i]   <= '0;
            end
        end else begin
            // Clear mapping at commit only if this ROB entry is still
            // the latest producer of that architectural register.
            if (commit_valid && commit_dest_reg != '0) begin
                if (
                    producer_valid[commit_dest_reg] &&
                    producer_tag[commit_dest_reg] == commit_tag
                ) begin
                    producer_valid[commit_dest_reg] <= 1'b0;
                    producer_tag[commit_dest_reg]   <= '0;
                end
            end

            // New rename update wins if rename and commit target the same
            // architectural register in the same cycle.
            if (rename_valid && rename_dest_reg != '0) begin
                producer_valid[rename_dest_reg] <= 1'b1;
                producer_tag[rename_dest_reg]   <= rename_dest_tag;
            end
        end
    end

endmodule

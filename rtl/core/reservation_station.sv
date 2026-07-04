`timescale 1ns/1ps

module reservation_station #(
    parameter int NUM_ENTRIES = 4,
    parameter int XLEN        = 32,
    parameter int TAG_W       = 3,
    parameter int OP_W        = 4,

    localparam int ENTRY_IDX_W = (NUM_ENTRIES <= 1) ? 1 : $clog2(NUM_ENTRIES),
    localparam int COUNT_W = $clog2(NUM_ENTRIES + 1)
) (
    input logic clk,
    input logic rst_n,

    // Dispatch interface
    input logic dispatch_valid,
    output logic dispatch_ready,
    input logic [OP_W-1:0] dispatch_op,

    input logic dispatch_src1_ready,
    input logic [XLEN-1:0] dispatch_src1_value,
    input logic [TAG_W-1:0] dispatch_src1_tag,

    input logic dispatch_src2_ready,
    input logic [XLEN-1:0] dispatch_src2_value,
    input logic [TAG_W-1:0] dispatch_src2_tag,

    input logic [TAG_W-1:0] dispatch_dest_tag,

    // CDB wakeup inferface
    input logic cdb_valid,
    input logic [TAG_W-1:0] cdb_tag,
    input logic [XLEN-1:0] cdb_value,

    // Issue interface
    output logic issue_valid,
    input logic issue_ready,
    output logic [OP_W-1:0] issue_op,
    output logic [XLEN-1:0] issue_src1_value,
    output logic [XLEN-1:0] issue_src2_value,
    output logic [TAG_W-1:0] issue_dest_tag,

    // Count used for testing/debugging
    output logic [COUNT_W-1:0] count
);

    logic busy [0:NUM_ENTRIES-1];
    logic [OP_W-1:0] op [0:NUM_ENTRIES-1];

    logic src1_ready [0:NUM_ENTRIES-1];
    logic [XLEN-1:0] src1_value [0:NUM_ENTRIES-1];
    logic [TAG_W-1:0] src1_tag [0:NUM_ENTRIES-1];

    logic src2_ready [0:NUM_ENTRIES-1];
    logic [XLEN-1:0] src2_value [0:NUM_ENTRIES-1];
    logic [TAG_W-1:0] src2_tag [0:NUM_ENTRIES-1];

    logic [TAG_W-1:0] dest_tag [0:NUM_ENTRIES-1];

    logic [ENTRY_IDX_W-1:0] free_idx;
    logic [ENTRY_IDX_W-1:0] issue_idx;

    logic found_free;
    logic found_ready_issue;

    logic dispatch_fire;
    logic issue_fire;

    assign dispatch_fire = dispatch_valid && dispatch_ready;
    assign issue_fire    = issue_valid && issue_ready;

    // Find first free entry
    always_comb begin
        found_free = 1'b0;
        free_idx   = '0;

        for (int i = 0; i < NUM_ENTRIES; i++) begin
            if (!busy[i] && !found_free) begin
                found_free = 1'b1;
                free_idx   = ENTRY_IDX_W'(i);
            end
        end
    end

    assign dispatch_ready = found_free;

    // Find first ready to issue entry
    always_comb begin
        found_ready_issue = 1'b0;
        issue_idx         = '0;

        for (int i = 0; i < NUM_ENTRIES; i++) begin
            if (busy[i] && src1_ready[i] && src2_ready[i] && !found_ready_issue) begin
                found_ready_issue = 1'b1;
                issue_idx         = ENTRY_IDX_W'(i);
            end
        end
    end

    assign issue_valid = found_ready_issue;
    assign issue_op = op[issue_idx];
    assign issue_src1_value = src1_value[issue_idx];
    assign issue_src2_value = src2_value[issue_idx];
    assign issue_dest_tag = dest_tag[issue_idx];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;

            for (int i = 0; i < NUM_ENTRIES; i++) begin
                busy[i] <= 1'b0;
                op[i] <= '0;

                src1_ready[i] <= 1'b0;
                src1_value[i] <= '0;
                src1_tag[i] <= '0;

                src2_ready[i] <= 1'b0;
                src2_value[i] <= '0;
                src2_tag[i] <= '0;

                dest_tag[i] <= '0;
            end
        end else begin
            // Wake up operands from the CDB
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                if (busy[i] && cdb_valid) begin
                    if (!src1_ready[i] && src1_tag[i] == cdb_tag) begin
                        src1_ready[i] <= 1'b1;
                        src1_value[i] <= cdb_value;
                    end

                    if (!src2_ready[i] && src2_tag[i] == cdb_tag) begin
                        src2_ready[i] <= 1'b1;
                        src2_value[i] <= cdb_value;
                    end
                end
            end

            // Allocate a new instruction into a free RS entry
            if (dispatch_fire) begin
                busy[free_idx] <= 1'b1;
                op[free_idx] <= dispatch_op;

                src1_ready[free_idx] <= dispatch_src1_ready;
                src1_value[free_idx] <= dispatch_src1_value;
                src1_tag[free_idx] <= dispatch_src1_tag;

                src2_ready[free_idx] <= dispatch_src2_ready;
                src2_value[free_idx] <= dispatch_src2_value;
                src2_tag[free_idx] <= dispatch_src2_tag;

                dest_tag[free_idx] <= dispatch_dest_tag;
            end

            // Remove an instruction once it issues to the FU
            if (issue_fire) begin
                busy[issue_idx] <= 1'b0;
                op[issue_idx] <= '0;

                src1_ready[issue_idx] <= 1'b0;
                src1_value[issue_idx] <= '0;
                src1_tag[issue_idx] <= '0;

                src2_ready[issue_idx] <= 1'b0;
                src2_value[issue_idx] <= '0;
                src2_tag[issue_idx] <= '0;

                dest_tag[issue_idx] <= '0;
            end

            case ({dispatch_fire, issue_fire})
                2'b00: count <= count;
                2'b01: count <= count - 1'b1;
                2'b10: count <= count + 1'b1;
                2'b11: count <= count;
            endcase
        end
    end

endmodule

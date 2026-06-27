`timescale 1ns/1ps

module rob #(
    parameter int NUM_ENTRIES = 8,
    parameter int REG_ADDR_W = 3,
    parameter int XLEN = 32,

    localparam int ROB_TAG_W = (NUM_ENTRIES <= 1) ? 1 : $clog2(NUM_ENTRIES),
    localparam int COUNT_W = $clog2(NUM_ENTRIES + 1)
) (
    input logic clk,
    input logic rst_n,

    // Used by issue/rename stage
    input logic alloc_valid,
    output logic alloc_ready,
    input logic [REG_ADDR_W-1:0] alloc_dest_reg,
    output logic [ROB_TAG_W-1:0] alloc_tag,

    // Used by CDB/FU for writeback
    input logic wb_valid,
    input logic [ROB_TAG_W-1:0] wb_tag,
    input logic [XLEN-1:0] wb_value,

    // Used by commit stage
    output logic commit_valid,
    input logic commit_ready,
    output logic [REG_ADDR_W-1:0] commit_dest_reg,
    output logic [XLEN-1:0] commit_value,
    output logic [ROB_TAG_W-1:0] commit_tag,

    // Count used for testing/debugging
    output logic [COUNT_W-1:0] count
);

    // Slot i is allocated and in use
    logic valid [0:NUM_ENTRIES-1];
    // Slot i has received execution result
    logic ready [0:NUM_ENTRIES-1];

    logic [REG_ADDR_W-1:0] dest_reg [0:NUM_ENTRIES-1];
    logic [XLEN-1:0] value [0:NUM_ENTRIES-1];


    // Circular buffer head and tail pointers
    logic [ROB_TAG_W-1:0] head;
    logic [ROB_TAG_W-1:0] tail;

    logic alloc_fire;
    logic commit_fire;

    assign alloc_ready = (count < COUNT_W'(NUM_ENTRIES));
    assign alloc_fire  = alloc_valid && alloc_ready;
    assign alloc_tag   = tail;

    assign commit_valid = valid[head] && ready[head];
    assign commit_fire  = commit_valid && commit_ready;

    assign commit_dest_reg = dest_reg[head];
    assign commit_value    = value[head];
    assign commit_tag      = head;

    function automatic logic [ROB_TAG_W-1:0] next_ptr(input logic [ROB_TAG_W-1:0] ptr);
        begin
            if (ptr == ROB_TAG_W'(NUM_ENTRIES-1)) begin
                next_ptr = '0;
            end else begin
                next_ptr = ptr + 1'b1;
            end
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head <= '0;
            tail <= '0;
            count <= '0;

            for (int i = 0; i < NUM_ENTRIES; i++) begin
                valid[i] <= 1'b0;
                ready[i] <= 1'b0;
                dest_reg[i] <= '0;
                value[i] <= '0;
            end
        end else begin
            if (alloc_fire) begin
                valid[tail] <= 1'b1;
                ready[tail] <= 1'b0;
                dest_reg[tail] <= alloc_dest_reg;
                value[tail] <= '0;
                tail <= next_ptr(tail);
            end

            if (wb_valid && valid[wb_tag]) begin
                ready[wb_tag] <= 1'b1;
                value[wb_tag] <= wb_value;
            end

            if (commit_fire) begin
                valid[head] <= 1'b0;
                ready[head] <= 1'b0;
                dest_reg[head] <= '0;
                value[head] <= '0;
                head <= next_ptr(head);
            end

            case ({alloc_fire, commit_fire})
                2'b00: count <= count;
                2'b01: count <= count - 1'b1;
                2'b10: count <= count + 1'b1;
                2'b11: count <= count;
            endcase
        end
    end

endmodule



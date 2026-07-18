`timescale 1ns/1ps

module backend_dependency_tb;

    localparam int NUM_ROB_ENTRIES = 4;
    localparam int NUM_RS_ENTRIES  = 4;
    localparam int XLEN            = 32;
    localparam int REG_ADDR_W      = 3;
    localparam int TAG_W           = $clog2(NUM_ROB_ENTRIES);
    localparam int OP_W            = 4;
    localparam int FU_LATENCY      = 3;
    localparam int ROB_COUNT_W     = $clog2(NUM_ROB_ENTRIES + 1);
    localparam int RS_COUNT_W      = $clog2(NUM_RS_ENTRIES + 1);

    localparam logic [OP_W-1:0] OP_ADD = 4'd0;

    logic clk;
    logic rst_n;

    // ROB allocate
    logic                  rob_alloc_valid;
    logic                  rob_alloc_ready;
    logic [REG_ADDR_W-1:0] rob_alloc_dest_reg;
    logic [TAG_W-1:0]      rob_alloc_tag;

    // ROB writeback from CDB
    logic                  rob_wb_valid;
    logic [TAG_W-1:0]      rob_wb_tag;
    logic [XLEN-1:0]       rob_wb_value;

    // ROB commit
    logic                  rob_commit_valid;
    logic                  rob_commit_ready;
    logic [REG_ADDR_W-1:0] rob_commit_dest_reg;
    logic [XLEN-1:0]       rob_commit_value;
    logic [TAG_W-1:0]      rob_commit_tag;

    logic [ROB_COUNT_W-1:0] rob_count;

    // RS dispatch
    logic             rs_dispatch_valid;
    logic             rs_dispatch_ready;
    logic [OP_W-1:0]  rs_dispatch_op;

    logic             rs_dispatch_src1_ready;
    logic [XLEN-1:0]  rs_dispatch_src1_value;
    logic [TAG_W-1:0] rs_dispatch_src1_tag;

    logic             rs_dispatch_src2_ready;
    logic [XLEN-1:0]  rs_dispatch_src2_value;
    logic [TAG_W-1:0] rs_dispatch_src2_tag;

    logic [TAG_W-1:0] rs_dispatch_dest_tag;

    // RS issue
    logic             rs_issue_valid;
    logic             rs_issue_ready;
    logic [OP_W-1:0]  rs_issue_op;
    logic [XLEN-1:0]  rs_issue_src1_value;
    logic [XLEN-1:0]  rs_issue_src2_value;
    logic [TAG_W-1:0] rs_issue_dest_tag;

    logic [RS_COUNT_W-1:0] rs_count;

    // FU
    logic             fu_start;
    logic             fu_busy;
    logic             fu_result_valid;
    logic [XLEN-1:0]  fu_result;
    logic [TAG_W-1:0] fu_result_tag;

    // CDB
    logic             cdb_valid;
    logic [TAG_W-1:0] cdb_tag;
    logic [XLEN-1:0]  cdb_value;

    rob #(
        .NUM_ENTRIES(NUM_ROB_ENTRIES),
        .REG_ADDR_W(REG_ADDR_W),
        .XLEN(XLEN)
    ) rob_dut (
        .clk(clk),
        .rst_n(rst_n),

        .alloc_valid(rob_alloc_valid),
        .alloc_ready(rob_alloc_ready),
        .alloc_dest_reg(rob_alloc_dest_reg),
        .alloc_tag(rob_alloc_tag),

        .wb_valid(rob_wb_valid),
        .wb_tag(rob_wb_tag),
        .wb_value(rob_wb_value),

        .commit_valid(rob_commit_valid),
        .commit_ready(rob_commit_ready),
        .commit_dest_reg(rob_commit_dest_reg),
        .commit_value(rob_commit_value),
        .commit_tag(rob_commit_tag),

        .count(rob_count)
    );

    reservation_station #(
        .NUM_ENTRIES(NUM_RS_ENTRIES),
        .XLEN(XLEN),
        .TAG_W(TAG_W),
        .OP_W(OP_W)
    ) rs_dut (
        .clk(clk),
        .rst_n(rst_n),

        .dispatch_valid(rs_dispatch_valid),
        .dispatch_ready(rs_dispatch_ready),
        .dispatch_op(rs_dispatch_op),

        .dispatch_src1_ready(rs_dispatch_src1_ready),
        .dispatch_src1_value(rs_dispatch_src1_value),
        .dispatch_src1_tag(rs_dispatch_src1_tag),

        .dispatch_src2_ready(rs_dispatch_src2_ready),
        .dispatch_src2_value(rs_dispatch_src2_value),
        .dispatch_src2_tag(rs_dispatch_src2_tag),

        .dispatch_dest_tag(rs_dispatch_dest_tag),

        .cdb_valid(cdb_valid),
        .cdb_tag(cdb_tag),
        .cdb_value(cdb_value),

        .issue_valid(rs_issue_valid),
        .issue_ready(rs_issue_ready),
        .issue_op(rs_issue_op),
        .issue_src1_value(rs_issue_src1_value),
        .issue_src2_value(rs_issue_src2_value),
        .issue_dest_tag(rs_issue_dest_tag),

        .count(rs_count)
    );

    fixed_latency_fu #(
        .WIDTH(XLEN),
        .TAG_WIDTH(TAG_W),
        .LATENCY(FU_LATENCY)
    ) fu_dut (
        .clk(clk),
        .rst_n(rst_n),

        .start(fu_start),
        .op(rs_issue_op),
        .a(rs_issue_src1_value),
        .b(rs_issue_src2_value),
        .tag_in(rs_issue_dest_tag),

        .busy(fu_busy),
        .result_valid(fu_result_valid),
        .result_ready(1'b1),
        .result(fu_result),
        .result_tag(fu_result_tag)
    );

    cdb #(
        .XLEN(XLEN),
        .TAG_WIDTH(TAG_W)
    ) cdb_dut (
        .fu_result_valid(fu_result_valid),
        .fu_result_tag(fu_result_tag),
        .fu_result_value(fu_result),

        .cdb_valid(cdb_valid),
        .cdb_tag(cdb_tag),
        .cdb_value(cdb_value)
    );

    assign rs_issue_ready = !fu_busy;
    assign fu_start       = rs_issue_valid && rs_issue_ready;

    assign rob_wb_valid = cdb_valid;
    assign rob_wb_tag   = cdb_tag;
    assign rob_wb_value = cdb_value;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic reset_dut;
        begin
            rst_n = 1'b0;

            rob_alloc_valid    = 1'b0;
            rob_alloc_dest_reg = '0;
            rob_commit_ready   = 1'b0;

            rs_dispatch_valid      = 1'b0;
            rs_dispatch_op         = '0;
            rs_dispatch_src1_ready = 1'b0;
            rs_dispatch_src1_value = '0;
            rs_dispatch_src1_tag   = '0;
            rs_dispatch_src2_ready = 1'b0;
            rs_dispatch_src2_value = '0;
            rs_dispatch_src2_tag   = '0;
            rs_dispatch_dest_tag   = '0;

            repeat (2) @(posedge clk);

            @(negedge clk);
            rst_n = 1'b1;

            @(posedge clk);
            #1;

            if (rob_count !== '0) begin
                $display("ERROR: ROB count should be 0 after reset, got %0d", rob_count);
                $fatal;
            end

            if (rs_count !== '0) begin
                $display("ERROR: RS count should be 0 after reset, got %0d", rs_count);
                $fatal;
            end

            $display("SUCCESS: reset");
        end
    endtask

    task automatic allocate_rob(
        input  logic [REG_ADDR_W-1:0] dest_reg,
        output logic [TAG_W-1:0]      tag_out
    );
        begin
            @(negedge clk);

            if (!rob_alloc_ready) begin
                $display("ERROR: tried to allocate ROB when full");
                $fatal;
            end

            rob_alloc_valid    = 1'b1;
            rob_alloc_dest_reg = dest_reg;

            #1;
            tag_out = rob_alloc_tag;

            @(posedge clk);
            #1;

            rob_alloc_valid    = 1'b0;
            rob_alloc_dest_reg = '0;

            $display("SUCCESS: allocated ROB%0d for R%0d", tag_out, dest_reg);
        end
    endtask

    task automatic dispatch_ready_add_to_rs(
        input logic [TAG_W-1:0] dest_tag,
        input logic [XLEN-1:0]  src1_value,
        input logic [XLEN-1:0]  src2_value
    );
        begin
            @(negedge clk);

            if (!rs_dispatch_ready) begin
                $display("ERROR: tried to dispatch when RS is full");
                $fatal;
            end

            rs_dispatch_valid      = 1'b1;
            rs_dispatch_op         = OP_ADD;

            rs_dispatch_src1_ready = 1'b1;
            rs_dispatch_src1_value = src1_value;
            rs_dispatch_src1_tag   = '0;

            rs_dispatch_src2_ready = 1'b1;
            rs_dispatch_src2_value = src2_value;
            rs_dispatch_src2_tag   = '0;

            rs_dispatch_dest_tag   = dest_tag;

            @(posedge clk);
            #1;

            rs_dispatch_valid      = 1'b0;
            rs_dispatch_op         = '0;
            rs_dispatch_src1_ready = 1'b0;
            rs_dispatch_src1_value = '0;
            rs_dispatch_src1_tag   = '0;
            rs_dispatch_src2_ready = 1'b0;
            rs_dispatch_src2_value = '0;
            rs_dispatch_src2_tag   = '0;
            rs_dispatch_dest_tag   = '0;

            $display(
                "SUCCESS: dispatched ready ADD %0d + %0d -> ROB%0d",
                src1_value,
                src2_value,
                dest_tag
            );
        end
    endtask

    task automatic dispatch_waiting_add_to_rs(
        input logic [TAG_W-1:0] dest_tag,
        input logic [TAG_W-1:0] waiting_src1_tag,
        input logic [XLEN-1:0]  src2_value
    );
        begin
            @(negedge clk);

            if (!rs_dispatch_ready) begin
                $display("ERROR: tried to dispatch when RS is full");
                $fatal;
            end

            rs_dispatch_valid      = 1'b1;
            rs_dispatch_op         = OP_ADD;

            // src1 is waiting for a previous ROB result.
            rs_dispatch_src1_ready = 1'b0;
            rs_dispatch_src1_value = '0;
            rs_dispatch_src1_tag   = waiting_src1_tag;

            // src2 is ready immediately.
            rs_dispatch_src2_ready = 1'b1;
            rs_dispatch_src2_value = src2_value;
            rs_dispatch_src2_tag   = '0;

            rs_dispatch_dest_tag   = dest_tag;

            @(posedge clk);
            #1;

            rs_dispatch_valid      = 1'b0;
            rs_dispatch_op         = '0;
            rs_dispatch_src1_ready = 1'b0;
            rs_dispatch_src1_value = '0;
            rs_dispatch_src1_tag   = '0;
            rs_dispatch_src2_ready = 1'b0;
            rs_dispatch_src2_value = '0;
            rs_dispatch_src2_tag   = '0;
            rs_dispatch_dest_tag   = '0;

            $display(
                "SUCCESS: dispatched waiting ADD ROB%0d + %0d -> ROB%0d",
                waiting_src1_tag,
                src2_value,
                dest_tag
            );
        end
    endtask

    task automatic wait_for_cdb_result(
        input logic [TAG_W-1:0] expected_tag,
        input logic [XLEN-1:0]  expected_value
    );
        begin
            while (!cdb_valid) begin
                @(posedge clk);
                #1;
            end

            if (cdb_tag !== expected_tag) begin
                $display(
                    "ERROR: expected CDB tag ROB%0d, got ROB%0d",
                    expected_tag,
                    cdb_tag
                );
                $fatal;
            end

            if (cdb_value !== expected_value) begin
                $display(
                    "ERROR: expected CDB value %0d, got %0d",
                    expected_value,
                    cdb_value
                );
                $fatal;
            end

            $display(
                "SUCCESS: CDB broadcast ROB%0d value=%0d",
                cdb_tag,
                cdb_value
            );

            // Wait for the CDB pulse to drop before looking for the next result.
            @(posedge clk);
            #1;
        end
    endtask

    task automatic commit_expect(
        input logic [TAG_W-1:0]      expected_tag,
        input logic [REG_ADDR_W-1:0] expected_dest_reg,
        input logic [XLEN-1:0]       expected_value
    );
        begin
            while (!rob_commit_valid) begin
                @(posedge clk);
                #1;
            end

            @(negedge clk);

            if (rob_commit_tag !== expected_tag) begin
                $display(
                    "ERROR: expected commit tag ROB%0d, got ROB%0d",
                    expected_tag,
                    rob_commit_tag
                );
                $fatal;
            end

            if (rob_commit_dest_reg !== expected_dest_reg) begin
                $display(
                    "ERROR: expected commit dest R%0d, got R%0d",
                    expected_dest_reg,
                    rob_commit_dest_reg
                );
                $fatal;
            end

            if (rob_commit_value !== expected_value) begin
                $display(
                    "ERROR: expected commit value %0d, got %0d",
                    expected_value,
                    rob_commit_value
                );
                $fatal;
            end

            rob_commit_ready = 1'b1;

            @(posedge clk);
            #1;

            rob_commit_ready = 1'b0;

            $display(
                "SUCCESS: committed ROB%0d to R%0d value=%0d",
                expected_tag,
                expected_dest_reg,
                expected_value
            );
        end
    endtask

    initial begin
        logic [TAG_W-1:0] tag0;
        logic [TAG_W-1:0] tag1;

        $dumpfile("backend_dependency_tb.vcd");
        $dumpvars(0, backend_dependency_tb);

        $display("INFO: FU latency = %0d cycles", FU_LATENCY);

        reset_dut();

        // I0: ADD R1 = 10 + 20 -> ROB0
        allocate_rob(3'd1, tag0);
        dispatch_ready_add_to_rs(tag0, 32'd10, 32'd20);

        // I1: ADD R2 = R1 + 5 -> ROB1
        // At dispatch time, R1 is not ready yet, so src1 waits on tag0.
        allocate_rob(3'd2, tag1);
        dispatch_waiting_add_to_rs(tag1, tag0, 32'd5);

        // I0 completes first and wakes up I1.
        wait_for_cdb_result(tag0, 32'd30);

        // I1 should wake up, issue, execute, and produce 35.
        wait_for_cdb_result(tag1, 32'd35);

        // ROB must still commit in program order.
        commit_expect(tag0, 3'd1, 32'd30);
        commit_expect(tag1, 3'd2, 32'd35);

        if (rob_count !== '0) begin
            $display("ERROR: expected ROB count 0 after commits, got %0d", rob_count);
            $fatal;
        end

        if (rs_count !== '0) begin
            $display("ERROR: expected RS count 0 after issues, got %0d", rs_count);
            $fatal;
        end

        $display("BACKEND DEPENDENCY WAKEUP TEST PASSED");
        $finish;
    end

endmodule

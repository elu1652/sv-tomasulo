`timescale 1ns/1ps

module rob_tb;

    localparam int NUM_ENTRIES = 4;
    localparam int XLEN        = 32;
    localparam int REG_ADDR_W  = 3;
    localparam int ROB_TAG_W   = $clog2(NUM_ENTRIES);
    localparam int COUNT_W     = $clog2(NUM_ENTRIES + 1);

    logic                  clk;
    logic                  rst_n;

    logic                  alloc_valid;
    logic                  alloc_ready;
    logic [REG_ADDR_W-1:0] alloc_dest_reg;
    logic [ROB_TAG_W-1:0]  alloc_tag;

    logic                  wb_valid;
    logic [ROB_TAG_W-1:0]  wb_tag;
    logic [XLEN-1:0]       wb_value;

    logic                  commit_valid;
    logic                  commit_ready;
    logic [REG_ADDR_W-1:0] commit_dest_reg;
    logic [XLEN-1:0]       commit_value;
    logic [ROB_TAG_W-1:0]  commit_tag;

    logic [COUNT_W-1:0]    count;

    rob #(
        .NUM_ENTRIES(NUM_ENTRIES),
        .XLEN(XLEN),
        .REG_ADDR_W(REG_ADDR_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .alloc_valid(alloc_valid),
        .alloc_ready(alloc_ready),
        .alloc_dest_reg(alloc_dest_reg),
        .alloc_tag(alloc_tag),

        .wb_valid(wb_valid),
        .wb_tag(wb_tag),
        .wb_value(wb_value),

        .commit_valid(commit_valid),
        .commit_ready(commit_ready),
        .commit_dest_reg(commit_dest_reg),
        .commit_value(commit_value),
        .commit_tag(commit_tag),

        .count(count)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic reset_dut;
        begin
            rst_n          = 1'b0;
            alloc_valid    = 1'b0;
            alloc_dest_reg = '0;
            wb_valid       = 1'b0;
            wb_tag         = '0;
            wb_value       = '0;
            commit_ready   = 1'b0;

            repeat(2) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;

            @(posedge clk);
            #1;

            if (count !== '0) begin
                $display("ERROR: count should be 0 after reset, got %0d", count);
                $fatal;
            end

            if (!alloc_ready) begin
                $display("ERROR: ROB should be ready to allocate after reset");
                $fatal;
            end

            if (commit_valid) begin
                $display("ERROR: ROB should not have commit_valid after reset");
                $fatal;
            end

            $display("SUCCESS: reset");
        end
    endtask

    task automatic alloc_entry(
        input logic [REG_ADDR_W-1:0] dest,
        output logic [ROB_TAG_W-1:0] tag_out
    );
        begin
            @(negedge clk);

            if (!alloc_ready) begin
                $display("ERROR: attempted to allocate when ROB is full");
                $fatal;
            end

            alloc_valid    = 1'b1;
            alloc_dest_reg = dest;

            #1;
            tag_out = alloc_tag;

            @(posedge clk);
            #1;

            alloc_valid    = 1'b0;
            alloc_dest_reg = '0;

            $display("SUCCESS: allocated ROB%0d for R%0d", tag_out, dest);
        end
    endtask

    task automatic writeback_entry(
        input logic [ROB_TAG_W-1:0] tag,
        input logic [XLEN-1:0]      value
    );
        begin
            @(negedge clk);

            wb_valid = 1'b1;
            wb_tag   = tag;
            wb_value = value;

            @(posedge clk);
            #1;

            wb_valid = 1'b0;
            wb_tag   = '0;
            wb_value = '0;

            $display("SUCCESS: wrote back ROB%0d with value %0h", tag, value);
        end
    endtask

    task automatic expect_no_commit;
        begin
            #1;

            if (commit_valid) begin
                $display(
                    "ERROR: expected no commit, but commit_valid=1 tag=%0d value=%0d",
                    commit_tag,
                    commit_value
                );
                $fatal;
            end

            $display("SUCCESS: no commit available");
        end
    endtask

    task automatic commit_expect (
        input logic [ROB_TAG_W-1:0]  expected_tag,
        input logic [REG_ADDR_W-1:0]  expected_dest,
        input logic [XLEN-1:0]       expected_value
    );
        begin
            @(negedge clk);

            if (!commit_valid) begin
                $display("ERROR: expected commit, but commit_valid=0");
                $fatal;
            end

            if (commit_tag !== expected_tag) begin
                $display(
                    "ERROR: expected commit tag=%0d, got %0d",
                    expected_tag,
                    commit_tag
                );
                $fatal;
            end

            if (commit_dest_reg !== expected_dest) begin
                $display(
                    "ERROR: expected commit dest R%0d, got R%0d",
                    expected_dest,
                    commit_dest_reg
                );
                $fatal;
            end

            if (commit_value !== expected_value) begin
                $display(
                    "ERROR: expected commit value=%0h, got %0h",
                    expected_value,
                    commit_value
                );
                $fatal;
            end

            commit_ready = 1'b1;

            @(posedge clk);
            #1;

            commit_ready = 1'b0;

            @(negedge clk);

            $display(
                "SUCCESS: committed ROB%0d R%0d value=%0h",
                expected_tag,
                expected_dest,
                expected_value
            );
        end
    endtask

    task automatic check_count(input logic [COUNT_W-1:0] expected);
        begin
            #1;
            if (count !== expected) begin
                $display("ERROR: expected count=%0d, got %0d", expected, count);
                $fatal;
            end else begin
                $display("SUCCESS: count=%0d", count);
            end
        end
    endtask

    initial begin
        logic [ROB_TAG_W-1:0] tag0, tag1, tag2, tag3, tag_wrap;

        $dumpfile("rob_tb.vcd");
        $dumpvars(0, rob_tb);

        reset_dut();

        alloc_entry(3'd1, tag0);
        alloc_entry(3'd2, tag1);
        alloc_entry(3'd3, tag2);
        check_count(COUNT_W'(3));

        writeback_entry(tag1, 32'd200);
        expect_no_commit(); // Should have no commits since tag0 is not ready yet.

        writeback_entry(tag0, 32'd100);
        commit_expect(tag0, 3'd1, 32'd100);
        check_count(COUNT_W'(2));

        commit_expect(tag1, 3'd2, 32'd200);
        check_count(COUNT_W'(1));

        expect_no_commit();

        writeback_entry(tag2, 32'd300);
        commit_expect(tag2, 3'd3, 32'd300);
        check_count(COUNT_W'(0));

        // Fill ROB to test full behavior.
        alloc_entry(3'd1, tag0);
        alloc_entry(3'd2, tag1);
        alloc_entry(3'd3, tag2);
        alloc_entry(3'd4, tag3);
        check_count(COUNT_W'(4));

        if (alloc_ready !== 1'b0) begin
            $display("ERROR: alloc_ready should be 0 when ROB is full");
            $fatal;
        end

        writeback_entry(tag0, 32'd11);
        commit_expect(tag0, 3'd1, 32'd11);
        check_count(COUNT_W'(3));

        alloc_entry(3'd5, tag_wrap);
        check_count(COUNT_W'(4));

        $display("SUCCESS: wraparound allocation got ROB%0d", tag_wrap);

        $display("ROB TEST PASSED");
        $finish;
    end

endmodule


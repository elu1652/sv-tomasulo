`timescale 1ns/1ps

module reservation_station_tb;

    localparam int NUM_ENTRIES = 4;
    localparam int XLEN        = 32;
    localparam int TAG_W       = 3;
    localparam int OP_W        = 4;
    localparam int COUNT_W     = $clog2(NUM_ENTRIES + 1);

    localparam logic [OP_W-1:0] OP_ADD = 4'd0;
    localparam logic [OP_W-1:0] OP_SUB = 4'd1;
    localparam logic [OP_W-1:0] OP_MUL = 4'd5;

    logic clk;
    logic rst_n;

    logic              dispatch_valid;
    logic              dispatch_ready;
    logic [OP_W-1:0]   dispatch_op;

    logic              dispatch_src1_ready;
    logic [XLEN-1:0]   dispatch_src1_value;
    logic [TAG_W-1:0]  dispatch_src1_tag;

    logic              dispatch_src2_ready;
    logic [XLEN-1:0]   dispatch_src2_value;
    logic [TAG_W-1:0]  dispatch_src2_tag;

    logic [TAG_W-1:0]  dispatch_dest_tag;

    logic              cdb_valid;
    logic [TAG_W-1:0]  cdb_tag;
    logic [XLEN-1:0]   cdb_value;

    logic              issue_valid;
    logic              issue_ready;
    logic [OP_W-1:0]   issue_op;
    logic [XLEN-1:0]   issue_src1_value;
    logic [XLEN-1:0]   issue_src2_value;
    logic [TAG_W-1:0]  issue_dest_tag;

    logic [COUNT_W-1:0] count;

    reservation_station #(
        .NUM_ENTRIES(NUM_ENTRIES),
        .XLEN(XLEN),
        .TAG_W(TAG_W),
        .OP_W(OP_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .dispatch_valid(dispatch_valid),
        .dispatch_ready(dispatch_ready),
        .dispatch_op(dispatch_op),

        .dispatch_src1_ready(dispatch_src1_ready),
        .dispatch_src1_value(dispatch_src1_value),
        .dispatch_src1_tag(dispatch_src1_tag),

        .dispatch_src2_ready(dispatch_src2_ready),
        .dispatch_src2_value(dispatch_src2_value),
        .dispatch_src2_tag(dispatch_src2_tag),

        .dispatch_dest_tag(dispatch_dest_tag),

        .cdb_valid(cdb_valid),
        .cdb_tag(cdb_tag),
        .cdb_value(cdb_value),

        .issue_valid(issue_valid),
        .issue_ready(issue_ready),
        .issue_op(issue_op),
        .issue_src1_value(issue_src1_value),
        .issue_src2_value(issue_src2_value),
        .issue_dest_tag(issue_dest_tag),

        .count(count)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic reset_dut;
        begin
            rst_n = 1'b0;

            dispatch_valid      = 1'b0;
            dispatch_op         = '0;
            dispatch_src1_ready = 1'b0;
            dispatch_src1_value = '0;
            dispatch_src1_tag   = '0;
            dispatch_src2_ready = 1'b0;
            dispatch_src2_value = '0;
            dispatch_src2_tag   = '0;
            dispatch_dest_tag   = '0;

            cdb_valid = 1'b0;
            cdb_tag   = '0;
            cdb_value = '0;

            issue_ready = 1'b0;

            repeat (2) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;

            @(posedge clk);
            #1;

            if (count !== '0) begin
                $display("ERROR: count should be 0 after reset, got %0d", count);
                $fatal;
            end

            if (!dispatch_ready) begin
                $display("ERROR: RS should be ready after reset");
                $fatal;
            end

            if (issue_valid) begin
                $display("ERROR: RS should not issue after reset");
                $fatal;
            end

            $display("SUCCESS: reset");
        end
    endtask

    task automatic dispatch_entry(
        input logic [OP_W-1:0]  op_in,
        input logic             src1_ready_in,
        input logic [XLEN-1:0]  src1_value_in,
        input logic [TAG_W-1:0] src1_tag_in,
        input logic             src2_ready_in,
        input logic [XLEN-1:0]  src2_value_in,
        input logic [TAG_W-1:0] src2_tag_in,
        input logic [TAG_W-1:0] dest_tag_in
    );
        begin
            @(negedge clk);

            issue_ready = 1'b0;

            if (!dispatch_ready) begin
                $display("ERROR: attempted to dispatch when RS full");
                $fatal;
            end

            dispatch_valid      = 1'b1;
            dispatch_op         = op_in;

            dispatch_src1_ready = src1_ready_in;
            dispatch_src1_value = src1_value_in;
            dispatch_src1_tag   = src1_tag_in;

            dispatch_src2_ready = src2_ready_in;
            dispatch_src2_value = src2_value_in;
            dispatch_src2_tag   = src2_tag_in;

            dispatch_dest_tag   = dest_tag_in;

            @(posedge clk);
            #1;

            dispatch_valid      = 1'b0;
            dispatch_op         = '0;
            dispatch_src1_ready = 1'b0;
            dispatch_src1_value = '0;
            dispatch_src1_tag   = '0;
            dispatch_src2_ready = 1'b0;
            dispatch_src2_value = '0;
            dispatch_src2_tag   = '0;
            dispatch_dest_tag   = '0;

            $display("SUCCESS: dispatched op=%0d dest_tag=%0d", op_in, dest_tag_in);
        end
    endtask

    task automatic cdb_broadcast(
        input logic [TAG_W-1:0] tag_in,
        input logic [XLEN-1:0]  value_in
    );
        begin
            @(negedge clk);

            cdb_valid = 1'b1;
            cdb_tag   = tag_in;
            cdb_value = value_in;

            @(posedge clk);
            #1;

            cdb_valid = 1'b0;
            cdb_tag   = '0;
            cdb_value = '0;

            $display("SUCCESS: CDB broadcast tag=%0d value=%0d", tag_in, value_in);
        end
    endtask

    task automatic expect_no_issue;
        begin
            #1;
            if (issue_valid) begin
                $display("ERROR: expected no issue, but issue_valid=1 op=%0d dest_tag=%0d", issue_op, issue_dest_tag);
                $fatal;
            end
            $display("SUCCESS: no issue available");
        end
    endtask

    task automatic issue_expect(
        input logic [OP_W-1:0]  expected_op,
        input logic [XLEN-1:0]  expected_src1_value,
        input logic [XLEN-1:0]  expected_src2_value,
        input logic [TAG_W-1:0] expected_dest_tag
    );
        begin
            @(negedge clk);

            if (!issue_valid) begin
                $display("ERROR: expected issue, but issue_valid=0");
                $fatal;
            end

            if (issue_op !== expected_op) begin
                $display(
                    "ERROR: expected issue op=%0d, got %0d",
                    expected_op,
                    issue_op
                );
                $fatal;
            end

            if (issue_src1_value !== expected_src1_value) begin
                $display(
                    "ERROR: expected issue src1_value=%0d, got %0d",
                    expected_src1_value,
                    issue_src1_value
                );
                $fatal;
            end

            if (issue_src2_value !== expected_src2_value) begin
                $display(
                    "ERROR: expected issue src2_value=%0d, got %0d",
                    expected_src2_value,
                    issue_src2_value
                );
                $fatal;
            end

            if (issue_dest_tag !== expected_dest_tag) begin
                $display(
                    "ERROR: expected issue dest_tag=%0d, got %0d",
                    expected_dest_tag,
                    issue_dest_tag
                );
                $fatal;
            end

            issue_ready = 1'b1;

            @(posedge clk);
            #1;

            issue_ready = 1'b0;

            $display(
                "SUCCESS: issued op=%0d src1=%0d src2=%0d dest_tag=%0d",
                expected_op,
                expected_src1_value,
                expected_src2_value,
                expected_dest_tag
            );
        end
    endtask

    task automatic check_count(input logic [COUNT_W-1:0] expected);
        begin
            #1;
            if (count !== expected) begin
                $display("ERROR: expected count=%0d, got %0d", expected, count);
                $fatal;
            end
            $display("SUCCESS: count=%0d", expected);
        end
    endtask

    initial begin
        $dumpfile("reservation_station_tb.vcd");
        $dumpvars(0, reservation_station_tb);

        reset_dut();

        // Test ready instruction can issue
        dispatch_entry(OP_ADD, 1'b1, 32'd10, '0, 1'b1, 32'd20, '0, 3'd1);
        check_count(COUNT_W'(1));

        issue_expect(OP_ADD, 32'd10, 32'd20, 3'd1);
        check_count(COUNT_W'(0));

        // Test waiting instruction does not issue until CDB broadcast
        dispatch_entry(
            OP_SUB,
            1'b0, 32'd0, 3'd2,
            1'b1, 32'd5, 3'd0,
            3'd3
        );
        check_count(COUNT_W'(1));

        expect_no_issue();

        cdb_broadcast(3'd2, 32'd50);

        issue_expect(OP_SUB, 32'd50, 32'd5, 3'd3);
        check_count(COUNT_W'(0));

        // Test two-source wakeup
        dispatch_entry(
            OP_MUL,
            1'b0, 32'd0, 3'd4,
            1'b0, 32'd0, 3'd5,
            3'd6
        );
        expect_no_issue();

        cdb_broadcast(3'd4, 32'd7);
        expect_no_issue();

        cdb_broadcast(3'd5, 32'd8);
        issue_expect(OP_MUL, 32'd7, 32'd8, 3'd6);
        check_count(COUNT_W'(0));

        // Fill RS to test dispatch_ready going low.
        dispatch_entry(OP_ADD, 1'b1, 32'd1, 3'd0, 1'b1, 32'd2, 3'd0, 3'd1);
        dispatch_entry(OP_ADD, 1'b1, 32'd3, 3'd0, 1'b1, 32'd4, 3'd0, 3'd2);
        dispatch_entry(OP_ADD, 1'b1, 32'd5, 3'd0, 1'b1, 32'd6, 3'd0, 3'd3);
        dispatch_entry(OP_ADD, 1'b1, 32'd7, 3'd0, 1'b1, 32'd8, 3'd0, 3'd4);

        check_count(COUNT_W'(4));

        if (dispatch_ready !== 1'b0) begin
            $display("ERROR: dispatch_ready should be 0 when RS is full");
            $fatal;
        end

        issue_expect(OP_ADD, 32'd1, 32'd2, 3'd1);
        check_count(COUNT_W'(3));

        if (dispatch_ready !== 1'b1) begin
            $display("ERROR: dispatch_ready should be 1 after issuing one entry");
            $fatal;
        end

        $display("RESERVATION STATION TEST PASSED");
        $finish;
    end

endmodule


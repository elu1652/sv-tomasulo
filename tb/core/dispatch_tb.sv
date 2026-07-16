`timescale 1ns/1ps

module dispatch_tb;

    localparam int XLEN       = 32;
    localparam int REG_ADDR_W = 3;
    localparam int TAG_W      = 2;
    localparam int OP_W       = 4;

    localparam logic [OP_W-1:0] OP_ADD = 4'd0;
    localparam logic [OP_W-1:0] OP_SUB = 4'd1;

    // ----------------------------------------------------------------
    // Decoded instruction input
    // ----------------------------------------------------------------

    logic                  dispatch_valid;
    logic                  dispatch_ready;

    logic [OP_W-1:0]       dispatch_op;
    logic [REG_ADDR_W-1:0] dispatch_src1_reg;
    logic [REG_ADDR_W-1:0] dispatch_src2_reg;
    logic [REG_ADDR_W-1:0] dispatch_dest_reg;

    // ----------------------------------------------------------------
    // Register-file lookup
    // ----------------------------------------------------------------

    logic [REG_ADDR_W-1:0] rf_raddr1;
    logic [REG_ADDR_W-1:0] rf_raddr2;
    logic [XLEN-1:0]       rf_rdata1;
    logic [XLEN-1:0]       rf_rdata2;

    // ----------------------------------------------------------------
    // Rename-table source lookup
    // ----------------------------------------------------------------

    logic [REG_ADDR_W-1:0] rename_src1_reg;
    logic                  rename_src1_pending;
    logic [TAG_W-1:0]      rename_src1_tag;

    logic [REG_ADDR_W-1:0] rename_src2_reg;
    logic                  rename_src2_pending;
    logic [TAG_W-1:0]      rename_src2_tag;

    // ----------------------------------------------------------------
    // ROB allocation
    // ----------------------------------------------------------------

    logic                  rob_alloc_valid;
    logic                  rob_alloc_ready;
    logic [REG_ADDR_W-1:0] rob_alloc_dest_reg;
    logic [TAG_W-1:0]      rob_alloc_tag;

    // ----------------------------------------------------------------
    // Rename-table destination update
    // ----------------------------------------------------------------

    logic                  rename_valid;
    logic [REG_ADDR_W-1:0] rename_dest_reg;
    logic [TAG_W-1:0]      rename_dest_tag;

    // ----------------------------------------------------------------
    // Reservation-station dispatch
    // ----------------------------------------------------------------

    logic                  rs_dispatch_valid;
    logic                  rs_dispatch_ready;
    logic [OP_W-1:0]       rs_dispatch_op;

    logic                  rs_dispatch_src1_ready;
    logic [XLEN-1:0]       rs_dispatch_src1_value;
    logic [TAG_W-1:0]      rs_dispatch_src1_tag;

    logic                  rs_dispatch_src2_ready;
    logic [XLEN-1:0]       rs_dispatch_src2_value;
    logic [TAG_W-1:0]      rs_dispatch_src2_tag;

    logic [TAG_W-1:0]      rs_dispatch_dest_tag;

    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------

    dispatch #(
        .XLEN(XLEN),
        .REG_ADDR_W(REG_ADDR_W),
        .TAG_W(TAG_W),
        .OP_W(OP_W)
    ) dut (
        .dispatch_valid(dispatch_valid),
        .dispatch_ready(dispatch_ready),

        .dispatch_op(dispatch_op),
        .dispatch_src1_reg(dispatch_src1_reg),
        .dispatch_src2_reg(dispatch_src2_reg),
        .dispatch_dest_reg(dispatch_dest_reg),

        .rf_raddr1(rf_raddr1),
        .rf_raddr2(rf_raddr2),
        .rf_rdata1(rf_rdata1),
        .rf_rdata2(rf_rdata2),

        .rename_src1_reg(rename_src1_reg),
        .rename_src1_pending(rename_src1_pending),
        .rename_src1_tag(rename_src1_tag),

        .rename_src2_reg(rename_src2_reg),
        .rename_src2_pending(rename_src2_pending),
        .rename_src2_tag(rename_src2_tag),

        .rob_alloc_valid(rob_alloc_valid),
        .rob_alloc_ready(rob_alloc_ready),
        .rob_alloc_dest_reg(rob_alloc_dest_reg),
        .rob_alloc_tag(rob_alloc_tag),

        .rename_valid(rename_valid),
        .rename_dest_reg(rename_dest_reg),
        .rename_dest_tag(rename_dest_tag),

        .rs_dispatch_valid(rs_dispatch_valid),
        .rs_dispatch_ready(rs_dispatch_ready),
        .rs_dispatch_op(rs_dispatch_op),

        .rs_dispatch_src1_ready(rs_dispatch_src1_ready),
        .rs_dispatch_src1_value(rs_dispatch_src1_value),
        .rs_dispatch_src1_tag(rs_dispatch_src1_tag),

        .rs_dispatch_src2_ready(rs_dispatch_src2_ready),
        .rs_dispatch_src2_value(rs_dispatch_src2_value),
        .rs_dispatch_src2_tag(rs_dispatch_src2_tag),

        .rs_dispatch_dest_tag(rs_dispatch_dest_tag)
    );

    // ----------------------------------------------------------------
    // Helpers
    // ----------------------------------------------------------------

    task automatic set_defaults;
        begin
            dispatch_valid     = 1'b0;
            dispatch_op        = '0;
            dispatch_src1_reg  = '0;
            dispatch_src2_reg  = '0;
            dispatch_dest_reg  = '0;

            rf_rdata1 = '0;
            rf_rdata2 = '0;

            rename_src1_pending = 1'b0;
            rename_src1_tag     = '0;
            rename_src2_pending = 1'b0;
            rename_src2_tag     = '0;

            rob_alloc_ready = 1'b0;
            rob_alloc_tag   = '0;

            rs_dispatch_ready = 1'b0;

            #1;
        end
    endtask

    task automatic expect_control_outputs(
        input logic expected_ready,
        input logic expected_fire
    );
        begin
            if (dispatch_ready !== expected_ready) begin
                $display(
                    "ERROR: expected dispatch_ready=%0b, got %0b",
                    expected_ready,
                    dispatch_ready
                );
                $fatal;
            end

            if (rob_alloc_valid !== expected_fire) begin
                $display(
                    "ERROR: expected rob_alloc_valid=%0b, got %0b",
                    expected_fire,
                    rob_alloc_valid
                );
                $fatal;
            end

            if (rename_valid !== expected_fire) begin
                $display(
                    "ERROR: expected rename_valid=%0b, got %0b",
                    expected_fire,
                    rename_valid
                );
                $fatal;
            end

            if (rs_dispatch_valid !== expected_fire) begin
                $display(
                    "ERROR: expected rs_dispatch_valid=%0b, got %0b",
                    expected_fire,
                    rs_dispatch_valid
                );
                $fatal;
            end
        end
    endtask

    task automatic expect_lookup_addresses(
        input logic [REG_ADDR_W-1:0] expected_src1,
        input logic [REG_ADDR_W-1:0] expected_src2
    );
        begin
            if (rf_raddr1 !== expected_src1) begin
                $display(
                    "ERROR: expected rf_raddr1=R%0d, got R%0d",
                    expected_src1,
                    rf_raddr1
                );
                $fatal;
            end

            if (rf_raddr2 !== expected_src2) begin
                $display(
                    "ERROR: expected rf_raddr2=R%0d, got R%0d",
                    expected_src2,
                    rf_raddr2
                );
                $fatal;
            end

            if (rename_src1_reg !== expected_src1) begin
                $display(
                    "ERROR: expected rename_src1_reg=R%0d, got R%0d",
                    expected_src1,
                    rename_src1_reg
                );
                $fatal;
            end

            if (rename_src2_reg !== expected_src2) begin
                $display(
                    "ERROR: expected rename_src2_reg=R%0d, got R%0d",
                    expected_src2,
                    rename_src2_reg
                );
                $fatal;
            end
        end
    endtask

    task automatic expect_destination_outputs(
        input logic [REG_ADDR_W-1:0] expected_dest_reg,
        input logic [TAG_W-1:0]      expected_dest_tag
    );
        begin
            if (rob_alloc_dest_reg !== expected_dest_reg) begin
                $display(
                    "ERROR: expected ROB destination R%0d, got R%0d",
                    expected_dest_reg,
                    rob_alloc_dest_reg
                );
                $fatal;
            end

            if (rename_dest_reg !== expected_dest_reg) begin
                $display(
                    "ERROR: expected rename destination R%0d, got R%0d",
                    expected_dest_reg,
                    rename_dest_reg
                );
                $fatal;
            end

            if (rename_dest_tag !== expected_dest_tag) begin
                $display(
                    "ERROR: expected rename tag ROB%0d, got ROB%0d",
                    expected_dest_tag,
                    rename_dest_tag
                );
                $fatal;
            end

            if (rs_dispatch_dest_tag !== expected_dest_tag) begin
                $display(
                    "ERROR: expected RS destination ROB%0d, got ROB%0d",
                    expected_dest_tag,
                    rs_dispatch_dest_tag
                );
                $fatal;
            end
        end
    endtask

    // ----------------------------------------------------------------
    // Test sequence
    // ----------------------------------------------------------------

    initial begin
        $dumpfile("dispatch_tb.vcd");
        $dumpvars(0, dispatch_tb);

        set_defaults();

        // ------------------------------------------------------------
        // Test 1: both sources ready from the register file
        // ------------------------------------------------------------

        dispatch_valid    = 1'b1;
        dispatch_op       = OP_ADD;
        dispatch_src1_reg = 3'd2;
        dispatch_src2_reg = 3'd3;
        dispatch_dest_reg = 3'd1;

        rf_rdata1 = 32'd10;
        rf_rdata2 = 32'd20;

        rename_src1_pending = 1'b0;
        rename_src2_pending = 1'b0;

        rob_alloc_ready = 1'b1;
        rob_alloc_tag   = 2'd0;

        rs_dispatch_ready = 1'b1;

        #1;

        expect_control_outputs(1'b1, 1'b1);
        expect_lookup_addresses(3'd2, 3'd3);
        expect_destination_outputs(3'd1, 2'd0);

        if (rs_dispatch_op !== OP_ADD) begin
            $display("ERROR: operation was not forwarded correctly");
            $fatal;
        end

        if (
            !rs_dispatch_src1_ready ||
            rs_dispatch_src1_value !== 32'd10 ||
            rs_dispatch_src1_tag !== '0
        ) begin
            $display("ERROR: source 1 ready-value conversion failed");
            $fatal;
        end

        if (
            !rs_dispatch_src2_ready ||
            rs_dispatch_src2_value !== 32'd20 ||
            rs_dispatch_src2_tag !== '0
        ) begin
            $display("ERROR: source 2 ready-value conversion failed");
            $fatal;
        end

        $display("SUCCESS: both sources ready");

        // ------------------------------------------------------------
        // Test 2: source 1 pending, source 2 ready
        // ADD R4, R1, R5
        // R1 waits for ROB0, R5 contains 5, destination receives ROB1
        // ------------------------------------------------------------

        dispatch_op       = OP_ADD;
        dispatch_src1_reg = 3'd1;
        dispatch_src2_reg = 3'd5;
        dispatch_dest_reg = 3'd4;

        rf_rdata1 = 32'd99;
        rf_rdata2 = 32'd5;

        rename_src1_pending = 1'b1;
        rename_src1_tag     = 2'd0;

        rename_src2_pending = 1'b0;
        rename_src2_tag     = '0;

        rob_alloc_tag = 2'd1;

        #1;

        expect_control_outputs(1'b1, 1'b1);
        expect_lookup_addresses(3'd1, 3'd5);
        expect_destination_outputs(3'd4, 2'd1);

        if (
            rs_dispatch_src1_ready !== 1'b0 ||
            rs_dispatch_src1_value !== '0 ||
            rs_dispatch_src1_tag !== 2'd0
        ) begin
            $display("ERROR: source 1 pending-tag conversion failed");
            $fatal;
        end

        if (
            rs_dispatch_src2_ready !== 1'b1 ||
            rs_dispatch_src2_value !== 32'd5 ||
            rs_dispatch_src2_tag !== '0
        ) begin
            $display("ERROR: source 2 ready-value conversion failed");
            $fatal;
        end

        $display("SUCCESS: source 1 pending, source 2 ready");

        // ------------------------------------------------------------
        // Test 3: source 1 ready, source 2 pending
        // ------------------------------------------------------------

        dispatch_op       = OP_SUB;
        dispatch_src1_reg = 3'd2;
        dispatch_src2_reg = 3'd6;
        dispatch_dest_reg = 3'd7;

        rf_rdata1 = 32'd40;
        rf_rdata2 = 32'd123;

        rename_src1_pending = 1'b0;
        rename_src1_tag     = '0;

        rename_src2_pending = 1'b1;
        rename_src2_tag     = 2'd2;

        rob_alloc_tag = 2'd3;

        #1;

        expect_control_outputs(1'b1, 1'b1);
        expect_lookup_addresses(3'd2, 3'd6);
        expect_destination_outputs(3'd7, 2'd3);

        if (
            rs_dispatch_src1_ready !== 1'b1 ||
            rs_dispatch_src1_value !== 32'd40 ||
            rs_dispatch_src1_tag !== '0
        ) begin
            $display("ERROR: source 1 ready-value conversion failed");
            $fatal;
        end

        if (
            rs_dispatch_src2_ready !== 1'b0 ||
            rs_dispatch_src2_value !== '0 ||
            rs_dispatch_src2_tag !== 2'd2
        ) begin
            $display("ERROR: source 2 pending-tag conversion failed");
            $fatal;
        end

        if (rs_dispatch_op !== OP_SUB) begin
            $display("ERROR: SUB operation was not forwarded correctly");
            $fatal;
        end

        $display("SUCCESS: source 1 ready, source 2 pending");

        // ------------------------------------------------------------
        // Test 4: both sources pending
        // ------------------------------------------------------------

        dispatch_op       = OP_ADD;
        dispatch_src1_reg = 3'd1;
        dispatch_src2_reg = 3'd4;
        dispatch_dest_reg = 3'd6;

        rename_src1_pending = 1'b1;
        rename_src1_tag     = 2'd1;

        rename_src2_pending = 1'b1;
        rename_src2_tag     = 2'd2;

        rob_alloc_tag = 2'd3;

        #1;

        expect_control_outputs(1'b1, 1'b1);
        expect_lookup_addresses(3'd1, 3'd4);
        expect_destination_outputs(3'd6, 2'd3);

        if (
            rs_dispatch_src1_ready !== 1'b0 ||
            rs_dispatch_src1_value !== '0 ||
            rs_dispatch_src1_tag !== 2'd1
        ) begin
            $display("ERROR: source 1 pending conversion failed");
            $fatal;
        end

        if (
            rs_dispatch_src2_ready !== 1'b0 ||
            rs_dispatch_src2_value !== '0 ||
            rs_dispatch_src2_tag !== 2'd2
        ) begin
            $display("ERROR: source 2 pending conversion failed");
            $fatal;
        end

        $display("SUCCESS: both sources pending");

        // ------------------------------------------------------------
        // Test 5: ROB full blocks dispatch
        // ------------------------------------------------------------

        rob_alloc_ready  = 1'b0;
        rs_dispatch_ready = 1'b1;
        dispatch_valid    = 1'b1;

        #1;

        expect_control_outputs(1'b0, 1'b0);

        $display("SUCCESS: ROB backpressure blocks dispatch");

        // ------------------------------------------------------------
        // Test 6: RS full blocks dispatch
        // ------------------------------------------------------------

        rob_alloc_ready   = 1'b1;
        rs_dispatch_ready = 1'b0;

        #1;

        expect_control_outputs(1'b0, 1'b0);

        $display("SUCCESS: RS backpressure blocks dispatch");

        // ------------------------------------------------------------
        // Test 7: both downstream structures unavailable
        // ------------------------------------------------------------

        rob_alloc_ready   = 1'b0;
        rs_dispatch_ready = 1'b0;

        #1;

        expect_control_outputs(1'b0, 1'b0);

        $display("SUCCESS: combined backpressure blocks dispatch");

        // ------------------------------------------------------------
        // Test 8: downstream ready, but no valid instruction
        // ------------------------------------------------------------

        rob_alloc_ready   = 1'b1;
        rs_dispatch_ready = 1'b1;
        dispatch_valid    = 1'b0;

        #1;

        expect_control_outputs(1'b1, 1'b0);

        $display("SUCCESS: invalid input causes no state updates");

        $display("DISPATCH TEST PASSED");
        $finish;
    end

endmodule

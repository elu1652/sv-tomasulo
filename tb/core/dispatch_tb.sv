`timescale 1ns/1ps

module dispatch_tb;

    localparam int XLEN       = 32;
    localparam int REG_ADDR_W = 3;
    localparam int TAG_W      = 2;
    localparam int OP_W       = 4;

    localparam logic [OP_W-1:0] OP_ADD = 4'd0;
    localparam logic [OP_W-1:0] OP_SUB = 4'd1;
    localparam logic [OP_W-1:0] OP_MUL = 4'd5;

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
    // ALU reservation-station dispatch
    // ----------------------------------------------------------------

    logic                  alu_rs_dispatch_valid;
    logic                  alu_rs_dispatch_ready;
    logic [OP_W-1:0]       alu_rs_dispatch_op;

    logic                  alu_rs_dispatch_src1_ready;
    logic [XLEN-1:0]       alu_rs_dispatch_src1_value;
    logic [TAG_W-1:0]      alu_rs_dispatch_src1_tag;

    logic                  alu_rs_dispatch_src2_ready;
    logic [XLEN-1:0]       alu_rs_dispatch_src2_value;
    logic [TAG_W-1:0]      alu_rs_dispatch_src2_tag;

    logic [TAG_W-1:0]      alu_rs_dispatch_dest_tag;

    // ----------------------------------------------------------------
    // Multiply reservation-station dispatch
    // ----------------------------------------------------------------

    logic                  mul_rs_dispatch_valid;
    logic                  mul_rs_dispatch_ready;
    logic [OP_W-1:0]       mul_rs_dispatch_op;

    logic                  mul_rs_dispatch_src1_ready;
    logic [XLEN-1:0]       mul_rs_dispatch_src1_value;
    logic [TAG_W-1:0]      mul_rs_dispatch_src1_tag;

    logic                  mul_rs_dispatch_src2_ready;
    logic [XLEN-1:0]       mul_rs_dispatch_src2_value;
    logic [TAG_W-1:0]      mul_rs_dispatch_src2_tag;

    logic [TAG_W-1:0]      mul_rs_dispatch_dest_tag;

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

        .alu_rs_dispatch_valid(alu_rs_dispatch_valid),
        .alu_rs_dispatch_ready(alu_rs_dispatch_ready),
        .alu_rs_dispatch_op(alu_rs_dispatch_op),

        .alu_rs_dispatch_src1_ready(alu_rs_dispatch_src1_ready),
        .alu_rs_dispatch_src1_value(alu_rs_dispatch_src1_value),
        .alu_rs_dispatch_src1_tag(alu_rs_dispatch_src1_tag),

        .alu_rs_dispatch_src2_ready(alu_rs_dispatch_src2_ready),
        .alu_rs_dispatch_src2_value(alu_rs_dispatch_src2_value),
        .alu_rs_dispatch_src2_tag(alu_rs_dispatch_src2_tag),

        .alu_rs_dispatch_dest_tag(alu_rs_dispatch_dest_tag),

        .mul_rs_dispatch_valid(mul_rs_dispatch_valid),
        .mul_rs_dispatch_ready(mul_rs_dispatch_ready),
        .mul_rs_dispatch_op(mul_rs_dispatch_op),

        .mul_rs_dispatch_src1_ready(mul_rs_dispatch_src1_ready),
        .mul_rs_dispatch_src1_value(mul_rs_dispatch_src1_value),
        .mul_rs_dispatch_src1_tag(mul_rs_dispatch_src1_tag),

        .mul_rs_dispatch_src2_ready(mul_rs_dispatch_src2_ready),
        .mul_rs_dispatch_src2_value(mul_rs_dispatch_src2_value),
        .mul_rs_dispatch_src2_tag(mul_rs_dispatch_src2_tag),

        .mul_rs_dispatch_dest_tag(mul_rs_dispatch_dest_tag)
    );

    // ----------------------------------------------------------------
    // Helpers
    // ----------------------------------------------------------------

    task automatic set_defaults;
        begin
            dispatch_valid    = 1'b0;
            dispatch_op       = '0;
            dispatch_src1_reg = '0;
            dispatch_src2_reg = '0;
            dispatch_dest_reg = '0;

            rf_rdata1 = '0;
            rf_rdata2 = '0;

            rename_src1_pending = 1'b0;
            rename_src1_tag     = '0;

            rename_src2_pending = 1'b0;
            rename_src2_tag     = '0;

            rob_alloc_ready = 1'b0;
            rob_alloc_tag   = '0;

            alu_rs_dispatch_ready = 1'b0;
            mul_rs_dispatch_ready = 1'b0;

            #1;
        end
    endtask

    task automatic expect_control_outputs(
        input logic expected_ready,
        input logic expected_fire,
        input logic expected_alu_valid,
        input logic expected_mul_valid
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

            if (alu_rs_dispatch_valid !== expected_alu_valid) begin
                $display(
                    "ERROR: expected alu_rs_dispatch_valid=%0b, got %0b",
                    expected_alu_valid,
                    alu_rs_dispatch_valid
                );
                $fatal;
            end

            if (mul_rs_dispatch_valid !== expected_mul_valid) begin
                $display(
                    "ERROR: expected mul_rs_dispatch_valid=%0b, got %0b",
                    expected_mul_valid,
                    mul_rs_dispatch_valid
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

            if (alu_rs_dispatch_dest_tag !== expected_dest_tag) begin
                $display(
                    "ERROR: expected ALU RS destination ROB%0d, got ROB%0d",
                    expected_dest_tag,
                    alu_rs_dispatch_dest_tag
                );
                $fatal;
            end

            if (mul_rs_dispatch_dest_tag !== expected_dest_tag) begin
                $display(
                    "ERROR: expected MUL RS destination ROB%0d, got ROB%0d",
                    expected_dest_tag,
                    mul_rs_dispatch_dest_tag
                );
                $fatal;
            end
        end
    endtask

    task automatic expect_alu_operands(
        input logic             expected_src1_ready,
        input logic [XLEN-1:0]  expected_src1_value,
        input logic [TAG_W-1:0] expected_src1_tag,

        input logic             expected_src2_ready,
        input logic [XLEN-1:0]  expected_src2_value,
        input logic [TAG_W-1:0] expected_src2_tag
    );
        begin
            if (
                alu_rs_dispatch_src1_ready !== expected_src1_ready ||
                alu_rs_dispatch_src1_value !== expected_src1_value ||
                alu_rs_dispatch_src1_tag   !== expected_src1_tag
            ) begin
                $display("ERROR: incorrect ALU RS source 1 packet");
                $fatal;
            end

            if (
                alu_rs_dispatch_src2_ready !== expected_src2_ready ||
                alu_rs_dispatch_src2_value !== expected_src2_value ||
                alu_rs_dispatch_src2_tag   !== expected_src2_tag
            ) begin
                $display("ERROR: incorrect ALU RS source 2 packet");
                $fatal;
            end
        end
    endtask

    task automatic expect_mul_operands(
        input logic             expected_src1_ready,
        input logic [XLEN-1:0]  expected_src1_value,
        input logic [TAG_W-1:0] expected_src1_tag,

        input logic             expected_src2_ready,
        input logic [XLEN-1:0]  expected_src2_value,
        input logic [TAG_W-1:0] expected_src2_tag
    );
        begin
            if (
                mul_rs_dispatch_src1_ready !== expected_src1_ready ||
                mul_rs_dispatch_src1_value !== expected_src1_value ||
                mul_rs_dispatch_src1_tag   !== expected_src1_tag
            ) begin
                $display("ERROR: incorrect MUL RS source 1 packet");
                $fatal;
            end

            if (
                mul_rs_dispatch_src2_ready !== expected_src2_ready ||
                mul_rs_dispatch_src2_value !== expected_src2_value ||
                mul_rs_dispatch_src2_tag   !== expected_src2_tag
            ) begin
                $display("ERROR: incorrect MUL RS source 2 packet");
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
        // Test 1: ADD routes to ALU RS with both sources ready
        // ADD R1, R2, R3
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

        alu_rs_dispatch_ready = 1'b1;
        mul_rs_dispatch_ready = 1'b1;

        #1;

        expect_control_outputs(
            1'b1,
            1'b1,
            1'b1,
            1'b0
        );

        expect_lookup_addresses(3'd2, 3'd3);
        expect_destination_outputs(3'd1, 2'd0);

        if (alu_rs_dispatch_op !== OP_ADD) begin
            $display("ERROR: ADD operation was not sent to ALU RS");
            $fatal;
        end

        expect_alu_operands(
            1'b1,
            32'd10,
            '0,
            1'b1,
            32'd20,
            '0
        );

        $display("SUCCESS: ADD routed to ALU RS");

        // ------------------------------------------------------------
        // Test 2: MUL routes to MUL RS
        // MUL R4, R1, R5
        // R1 waits for ROB0; R5 contains 5
        // ------------------------------------------------------------

        dispatch_op       = OP_MUL;
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

        expect_control_outputs(
            1'b1,
            1'b1,
            1'b0,
            1'b1
        );

        expect_lookup_addresses(3'd1, 3'd5);
        expect_destination_outputs(3'd4, 2'd1);

        if (mul_rs_dispatch_op !== OP_MUL) begin
            $display("ERROR: MUL operation was not sent to MUL RS");
            $fatal;
        end

        expect_mul_operands(
            1'b0,
            '0,
            2'd0,
            1'b1,
            32'd5,
            '0
        );

        $display("SUCCESS: MUL routed to MUL RS");

        // ------------------------------------------------------------
        // Test 3: SUB routes to ALU RS with source 2 pending
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

        expect_control_outputs(
            1'b1,
            1'b1,
            1'b1,
            1'b0
        );

        expect_destination_outputs(3'd7, 2'd3);

        if (alu_rs_dispatch_op !== OP_SUB) begin
            $display("ERROR: SUB operation was not sent to ALU RS");
            $fatal;
        end

        expect_alu_operands(
            1'b1,
            32'd40,
            '0,
            1'b0,
            '0,
            2'd2
        );

        $display("SUCCESS: SUB routed to ALU RS with pending source");

        // ------------------------------------------------------------
        // Test 4: both pending operands route correctly to MUL RS
        // ------------------------------------------------------------

        dispatch_op       = OP_MUL;
        dispatch_src1_reg = 3'd1;
        dispatch_src2_reg = 3'd4;
        dispatch_dest_reg = 3'd6;

        rename_src1_pending = 1'b1;
        rename_src1_tag     = 2'd1;

        rename_src2_pending = 1'b1;
        rename_src2_tag     = 2'd2;

        rob_alloc_tag = 2'd3;

        #1;

        expect_control_outputs(
            1'b1,
            1'b1,
            1'b0,
            1'b1
        );

        expect_mul_operands(
            1'b0,
            '0,
            2'd1,
            1'b0,
            '0,
            2'd2
        );

        $display("SUCCESS: both pending operands sent to MUL RS");

        // ------------------------------------------------------------
        // Test 5: ROB full blocks ADD
        // ------------------------------------------------------------

        dispatch_op          = OP_ADD;
        dispatch_valid       = 1'b1;
        rob_alloc_ready      = 1'b0;
        alu_rs_dispatch_ready = 1'b1;
        mul_rs_dispatch_ready = 1'b1;

        #1;

        expect_control_outputs(
            1'b0,
            1'b0,
            1'b0,
            1'b0
        );

        $display("SUCCESS: ROB backpressure blocks ADD");

        // ------------------------------------------------------------
        // Test 6: ALU RS full blocks ADD
        // ------------------------------------------------------------

        rob_alloc_ready       = 1'b1;
        alu_rs_dispatch_ready = 1'b0;
        mul_rs_dispatch_ready = 1'b1;
        dispatch_op           = OP_ADD;

        #1;

        expect_control_outputs(
            1'b0,
            1'b0,
            1'b0,
            1'b0
        );

        $display("SUCCESS: ALU RS backpressure blocks ADD");

        // ------------------------------------------------------------
        // Test 7: MUL RS full blocks MUL
        // ------------------------------------------------------------

        alu_rs_dispatch_ready = 1'b1;
        mul_rs_dispatch_ready = 1'b0;
        dispatch_op           = OP_MUL;

        #1;

        expect_control_outputs(
            1'b0,
            1'b0,
            1'b0,
            1'b0
        );

        $display("SUCCESS: MUL RS backpressure blocks MUL");

        // ------------------------------------------------------------
        // Test 8: full MUL RS does not block ADD
        // ------------------------------------------------------------

        alu_rs_dispatch_ready = 1'b1;
        mul_rs_dispatch_ready = 1'b0;
        dispatch_op           = OP_ADD;

        #1;

        expect_control_outputs(
            1'b1,
            1'b1,
            1'b1,
            1'b0
        );

        $display("SUCCESS: MUL RS does not block ADD");

        // ------------------------------------------------------------
        // Test 9: full ALU RS does not block MUL
        // ------------------------------------------------------------

        alu_rs_dispatch_ready = 1'b0;
        mul_rs_dispatch_ready = 1'b1;
        dispatch_op           = OP_MUL;

        #1;

        expect_control_outputs(
            1'b1,
            1'b1,
            1'b0,
            1'b1
        );

        $display("SUCCESS: ALU RS does not block MUL");

        // ------------------------------------------------------------
        // Test 10: no valid instruction causes no state updates
        // ------------------------------------------------------------

        dispatch_valid        = 1'b0;
        rob_alloc_ready       = 1'b1;
        alu_rs_dispatch_ready = 1'b1;
        mul_rs_dispatch_ready = 1'b1;
        dispatch_op           = OP_ADD;

        #1;

        expect_control_outputs(
            1'b1,
            1'b0,
            1'b0,
            1'b0
        );

        $display("SUCCESS: invalid input causes no state updates");

        $display("DISPATCH TEST PASSED");
        $finish;
    end

endmodule

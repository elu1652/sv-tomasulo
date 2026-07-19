`timescale 1ns/1ps

module backend_cdb_collision_tb;

    localparam int NUM_ROB_ENTRIES = 4;
    localparam int NUM_RS_ENTRIES  = 2;
    localparam int NUM_REGS        = 8;

    localparam int XLEN       = 32;
    localparam int REG_ADDR_W = $clog2(NUM_REGS);
    localparam int TAG_W      = $clog2(NUM_ROB_ENTRIES);
    localparam int OP_W       = 4;

    localparam int ALU_LATENCY = 1;
    localparam int MUL_LATENCY = 2;

    localparam int ROB_COUNT_W = $clog2(NUM_ROB_ENTRIES + 1);
    localparam int RS_COUNT_W  = $clog2(NUM_RS_ENTRIES + 1);

    localparam logic [OP_W-1:0] OP_ADD = 4'd0;
    localparam logic [OP_W-1:0] OP_MUL = 4'd5;

    logic clk;
    logic rst_n;
    int unsigned cycle;

    logic collision_seen;
    logic alu_broadcast_seen;
    logic mul_broadcast_seen;

    logic [TAG_W-1:0] expected_mul_tag;
    logic [TAG_W-1:0] expected_add_tag;

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
    // Register file
    // ----------------------------------------------------------------

    logic [REG_ADDR_W-1:0] rf_raddr1;
    logic [REG_ADDR_W-1:0] rf_raddr2;
    logic [XLEN-1:0]       rf_rdata1;
    logic [XLEN-1:0]       rf_rdata2;

    logic                  rf_we;
    logic [REG_ADDR_W-1:0] rf_waddr;
    logic [XLEN-1:0]       rf_wdata;

    logic                  init_mode;
    logic                  init_we;
    logic [REG_ADDR_W-1:0] init_waddr;
    logic [XLEN-1:0]       init_wdata;

    // ----------------------------------------------------------------
    // Rename table
    // ----------------------------------------------------------------

    logic [REG_ADDR_W-1:0] rename_src1_reg;
    logic                  rename_src1_pending;
    logic [TAG_W-1:0]      rename_src1_tag;

    logic [REG_ADDR_W-1:0] rename_src2_reg;
    logic                  rename_src2_pending;
    logic [TAG_W-1:0]      rename_src2_tag;

    logic                  rename_valid;
    logic [REG_ADDR_W-1:0] rename_dest_reg;
    logic [TAG_W-1:0]      rename_dest_tag;

    logic                  rename_commit_valid;
    logic [REG_ADDR_W-1:0] rename_commit_dest_reg;
    logic [TAG_W-1:0]      rename_commit_tag;

    // ----------------------------------------------------------------
    // ROB
    // ----------------------------------------------------------------

    logic                  rob_alloc_valid;
    logic                  rob_alloc_ready;
    logic [REG_ADDR_W-1:0] rob_alloc_dest_reg;
    logic [TAG_W-1:0]      rob_alloc_tag;

    logic                  rob_wb_valid;
    logic [TAG_W-1:0]      rob_wb_tag;
    logic [XLEN-1:0]       rob_wb_value;

    logic                  rob_commit_valid;
    logic                  rob_commit_ready;
    logic [REG_ADDR_W-1:0] rob_commit_dest_reg;
    logic [XLEN-1:0]       rob_commit_value;
    logic [TAG_W-1:0]      rob_commit_tag;

    logic                   rob_commit_fire;
    logic [ROB_COUNT_W-1:0] rob_count;

    // ----------------------------------------------------------------
    // ALU reservation station
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

    logic                  alu_rs_issue_valid;
    logic                  alu_rs_issue_ready;
    logic [OP_W-1:0]       alu_rs_issue_op;
    logic [XLEN-1:0]       alu_rs_issue_src1_value;
    logic [XLEN-1:0]       alu_rs_issue_src2_value;
    logic [TAG_W-1:0]      alu_rs_issue_dest_tag;

    logic [RS_COUNT_W-1:0] alu_rs_count;

    // ----------------------------------------------------------------
    // MUL reservation station
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

    logic                  mul_rs_issue_valid;
    logic                  mul_rs_issue_ready;
    logic [OP_W-1:0]       mul_rs_issue_op;
    logic [XLEN-1:0]       mul_rs_issue_src1_value;
    logic [XLEN-1:0]       mul_rs_issue_src2_value;
    logic [TAG_W-1:0]      mul_rs_issue_dest_tag;

    logic [RS_COUNT_W-1:0] mul_rs_count;

    // ----------------------------------------------------------------
    // ALU functional unit
    // ----------------------------------------------------------------

    logic                  alu_fu_start;
    logic                  alu_fu_busy;
    logic                  alu_result_valid;
    logic                  alu_result_ready;
    logic [XLEN-1:0]       alu_result;
    logic [TAG_W-1:0]      alu_result_tag;

    // ----------------------------------------------------------------
    // MUL functional unit
    // ----------------------------------------------------------------

    logic                  mul_fu_start;
    logic                  mul_fu_busy;
    logic                  mul_result_valid;
    logic                  mul_result_ready;
    logic [XLEN-1:0]       mul_result;
    logic [TAG_W-1:0]      mul_result_tag;

    // ----------------------------------------------------------------
    // Common data bus
    // ----------------------------------------------------------------

    logic                  cdb_valid;
    logic [TAG_W-1:0]      cdb_tag;
    logic [XLEN-1:0]       cdb_value;

    // ----------------------------------------------------------------
    // Dispatch
    // ----------------------------------------------------------------

    dispatch #(
        .XLEN(XLEN),
        .REG_ADDR_W(REG_ADDR_W),
        .TAG_W(TAG_W),
        .OP_W(OP_W)
    ) dispatch_dut (
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
    // Register file
    // ----------------------------------------------------------------

    regfile #(
        .WIDTH(XLEN),
        .NUM_REGS(NUM_REGS)
    ) regfile_dut (
        .clk(clk),
        .rst_n(rst_n),

        .raddr1(rf_raddr1),
        .raddr2(rf_raddr2),
        .rdata1(rf_rdata1),
        .rdata2(rf_rdata2),

        .we(rf_we),
        .waddr(rf_waddr),
        .wdata(rf_wdata)
    );

    // ----------------------------------------------------------------
    // Rename table
    // ----------------------------------------------------------------

    rename_table #(
        .NUM_REGS(NUM_REGS),
        .REG_ADDR_W(REG_ADDR_W),
        .TAG_W(TAG_W)
    ) rename_dut (
        .clk(clk),
        .rst_n(rst_n),

        .src1_reg(rename_src1_reg),
        .src1_pending(rename_src1_pending),
        .src1_tag(rename_src1_tag),

        .src2_reg(rename_src2_reg),
        .src2_pending(rename_src2_pending),
        .src2_tag(rename_src2_tag),

        .rename_valid(rename_valid),
        .rename_dest_reg(rename_dest_reg),
        .rename_dest_tag(rename_dest_tag),

        .commit_valid(rename_commit_valid),
        .commit_dest_reg(rename_commit_dest_reg),
        .commit_tag(rename_commit_tag)
    );

    // ----------------------------------------------------------------
    // ROB
    // ----------------------------------------------------------------

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

    // ----------------------------------------------------------------
    // ALU reservation station
    // ----------------------------------------------------------------

    reservation_station #(
        .NUM_ENTRIES(NUM_RS_ENTRIES),
        .XLEN(XLEN),
        .TAG_W(TAG_W),
        .OP_W(OP_W)
    ) alu_rs_dut (
        .clk(clk),
        .rst_n(rst_n),

        .dispatch_valid(alu_rs_dispatch_valid),
        .dispatch_ready(alu_rs_dispatch_ready),
        .dispatch_op(alu_rs_dispatch_op),

        .dispatch_src1_ready(alu_rs_dispatch_src1_ready),
        .dispatch_src1_value(alu_rs_dispatch_src1_value),
        .dispatch_src1_tag(alu_rs_dispatch_src1_tag),

        .dispatch_src2_ready(alu_rs_dispatch_src2_ready),
        .dispatch_src2_value(alu_rs_dispatch_src2_value),
        .dispatch_src2_tag(alu_rs_dispatch_src2_tag),

        .dispatch_dest_tag(alu_rs_dispatch_dest_tag),

        .cdb_valid(cdb_valid),
        .cdb_tag(cdb_tag),
        .cdb_value(cdb_value),

        .issue_valid(alu_rs_issue_valid),
        .issue_ready(alu_rs_issue_ready),
        .issue_op(alu_rs_issue_op),
        .issue_src1_value(alu_rs_issue_src1_value),
        .issue_src2_value(alu_rs_issue_src2_value),
        .issue_dest_tag(alu_rs_issue_dest_tag),

        .count(alu_rs_count)
    );

    // ----------------------------------------------------------------
    // MUL reservation station
    // ----------------------------------------------------------------

    reservation_station #(
        .NUM_ENTRIES(NUM_RS_ENTRIES),
        .XLEN(XLEN),
        .TAG_W(TAG_W),
        .OP_W(OP_W)
    ) mul_rs_dut (
        .clk(clk),
        .rst_n(rst_n),

        .dispatch_valid(mul_rs_dispatch_valid),
        .dispatch_ready(mul_rs_dispatch_ready),
        .dispatch_op(mul_rs_dispatch_op),

        .dispatch_src1_ready(mul_rs_dispatch_src1_ready),
        .dispatch_src1_value(mul_rs_dispatch_src1_value),
        .dispatch_src1_tag(mul_rs_dispatch_src1_tag),

        .dispatch_src2_ready(mul_rs_dispatch_src2_ready),
        .dispatch_src2_value(mul_rs_dispatch_src2_value),
        .dispatch_src2_tag(mul_rs_dispatch_src2_tag),

        .dispatch_dest_tag(mul_rs_dispatch_dest_tag),

        .cdb_valid(cdb_valid),
        .cdb_tag(cdb_tag),
        .cdb_value(cdb_value),

        .issue_valid(mul_rs_issue_valid),
        .issue_ready(mul_rs_issue_ready),
        .issue_op(mul_rs_issue_op),
        .issue_src1_value(mul_rs_issue_src1_value),
        .issue_src2_value(mul_rs_issue_src2_value),
        .issue_dest_tag(mul_rs_issue_dest_tag),

        .count(mul_rs_count)
    );

    // ----------------------------------------------------------------
    // ALU functional unit
    // ----------------------------------------------------------------

    fixed_latency_fu #(
        .WIDTH(XLEN),
        .TAG_WIDTH(TAG_W),
        .LATENCY(ALU_LATENCY)
    ) alu_fu_dut (
        .clk(clk),
        .rst_n(rst_n),

        .start(alu_fu_start),
        .op(alu_rs_issue_op),
        .a(alu_rs_issue_src1_value),
        .b(alu_rs_issue_src2_value),
        .tag_in(alu_rs_issue_dest_tag),

        .busy(alu_fu_busy),
        .result_valid(alu_result_valid),
        .result_ready(alu_result_ready),
        .result(alu_result),
        .result_tag(alu_result_tag)
    );

    // ----------------------------------------------------------------
    // MUL functional unit
    // ----------------------------------------------------------------

    fixed_latency_fu #(
        .WIDTH(XLEN),
        .TAG_WIDTH(TAG_W),
        .LATENCY(MUL_LATENCY)
    ) mul_fu_dut (
        .clk(clk),
        .rst_n(rst_n),

        .start(mul_fu_start),
        .op(mul_rs_issue_op),
        .a(mul_rs_issue_src1_value),
        .b(mul_rs_issue_src2_value),
        .tag_in(mul_rs_issue_dest_tag),

        .busy(mul_fu_busy),
        .result_valid(mul_result_valid),
        .result_ready(mul_result_ready),
        .result(mul_result),
        .result_tag(mul_result_tag)
    );

    // ----------------------------------------------------------------
    // CDB arbiter
    // ----------------------------------------------------------------

    cdb_arbiter #(
        .XLEN(XLEN),
        .TAG_W(TAG_W)
    ) cdb_arbiter_dut (
        .src0_valid(alu_result_valid),
        .src0_tag(alu_result_tag),
        .src0_value(alu_result),
        .src0_ready(alu_result_ready),

        .src1_valid(mul_result_valid),
        .src1_tag(mul_result_tag),
        .src1_value(mul_result),
        .src1_ready(mul_result_ready),

        .cdb_valid(cdb_valid),
        .cdb_tag(cdb_tag),
        .cdb_value(cdb_value)
    );

    // ----------------------------------------------------------------
    // Backend wiring
    // ----------------------------------------------------------------

    assign alu_rs_issue_ready = !alu_fu_busy;
    assign alu_fu_start = alu_rs_issue_valid && alu_rs_issue_ready;

    assign mul_rs_issue_ready = !mul_fu_busy;
    assign mul_fu_start = mul_rs_issue_valid && mul_rs_issue_ready;

    assign rob_wb_valid = cdb_valid;
    assign rob_wb_tag   = cdb_tag;
    assign rob_wb_value = cdb_value;

    assign rob_commit_fire = rob_commit_valid && rob_commit_ready;

    assign rename_commit_valid = rob_commit_fire;

    assign rename_commit_dest_reg = rob_commit_dest_reg;

    assign rename_commit_tag = rob_commit_tag;

    always_comb begin
        if (init_mode) begin
            rf_we    = init_we;
            rf_waddr = init_waddr;
            rf_wdata = init_wdata;
        end else begin
            rf_we    = rob_commit_fire;
            rf_waddr = rob_commit_dest_reg;
            rf_wdata = rob_commit_value;
        end
    end

    // ----------------------------------------------------------------
    // Clock and event logging
    // ----------------------------------------------------------------

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            cycle              = 0;
            collision_seen     = 1'b0;
            alu_broadcast_seen = 1'b0;
            mul_broadcast_seen = 1'b0;
        end else begin
            cycle = cycle + 1;

            if (alu_rs_issue_valid && alu_rs_issue_ready) begin
                $display(
                    "[CYCLE %0d] ALU ISSUE ROB%0d: %0d + %0d",
                    cycle,
                    alu_rs_issue_dest_tag,
                    alu_rs_issue_src1_value,
                    alu_rs_issue_src2_value
                );
            end

            if (mul_rs_issue_valid && mul_rs_issue_ready) begin
                $display(
                    "[CYCLE %0d] MUL ISSUE ROB%0d: %0d * %0d",
                    cycle,
                    mul_rs_issue_dest_tag,
                    mul_rs_issue_src1_value,
                    mul_rs_issue_src2_value
                );
            end

            // Detect both FUs requesting the CDB simultaneously.
            if (alu_result_valid && mul_result_valid) begin
                collision_seen = 1'b1;

                $display(
                    "[CYCLE %0d] CDB COLLISION: ALU ROB%0d and MUL ROB%0d",
                    cycle,
                    alu_result_tag,
                    mul_result_tag
                );

                // Source 0 is the ALU, so it must win fixed-priority
                // arbitration.
                if (!alu_result_ready) begin
                    $display(
                        "ERROR: ALU should receive ready during collision"
                    );
                    $fatal;
                end

                if (mul_result_ready) begin
                    $display(
                        "ERROR: MUL should not receive ready during collision"
                    );
                    $fatal;
                end

                if (!cdb_valid) begin
                    $display(
                        "ERROR: CDB should be valid during collision"
                    );
                    $fatal;
                end

                if (cdb_tag !== expected_add_tag) begin
                    $display(
                        "ERROR: ALU should win collision with ROB%0d, got ROB%0d",
                        expected_add_tag,
                        cdb_tag
                    );
                    $fatal;
                end

                if (cdb_value !== 32'd15) begin
                    $display(
                        "ERROR: expected ALU collision result 15, got %0d",
                        cdb_value
                    );
                    $fatal;
                end
            end

            if (cdb_valid) begin
                $display(
                    "[CYCLE %0d] CDB ROB%0d = %0d",
                    cycle,
                    cdb_tag,
                    cdb_value
                );

                if (cdb_tag == expected_add_tag) begin
                    alu_broadcast_seen = 1'b1;
                end

                if (cdb_tag == expected_mul_tag) begin
                    mul_broadcast_seen = 1'b1;
                end
            end

            if (rob_commit_fire) begin
                $display(
                    "[CYCLE %0d] COMMIT ROB%0d -> R%0d = %0d",
                    cycle,
                    rob_commit_tag,
                    rob_commit_dest_reg,
                    rob_commit_value
                );
            end
        end
    end

    // ----------------------------------------------------------------
    // Testbench tasks
    // ----------------------------------------------------------------

    task automatic reset_dut;
        begin
            collision_seen      = 1'b0;
            alu_broadcast_seen  = 1'b0;
            mul_broadcast_seen  = 1'b0;

            expected_mul_tag = '0;
            expected_add_tag = '0;

            rst_n = 1'b0;

            init_mode  = 1'b1;
            init_we    = 1'b0;
            init_waddr = '0;
            init_wdata = '0;

            dispatch_valid    = 1'b0;
            dispatch_op       = '0;
            dispatch_src1_reg = '0;
            dispatch_src2_reg = '0;
            dispatch_dest_reg = '0;

            rob_commit_ready = 1'b0;

            repeat (2) @(posedge clk);

            @(negedge clk);
            rst_n = 1'b1;

            @(posedge clk);
            #1;

            if (rob_count !== '0) begin
                $display(
                    "ERROR: ROB count should be 0 after reset, got %0d",
                    rob_count
                );
                $fatal;
            end

            if (alu_rs_count !== '0) begin
                $display(
                    "ERROR: ALU RS count should be 0 after reset, got %0d",
                    alu_rs_count
                );
                $fatal;
            end

            if (mul_rs_count !== '0) begin
                $display(
                    "ERROR: MUL RS count should be 0 after reset, got %0d",
                    mul_rs_count
                );
                $fatal;
            end

            $display("SUCCESS: reset");
        end
    endtask

    task automatic initialize_register(
        input logic [REG_ADDR_W-1:0] reg_id,
        input logic [XLEN-1:0]       value
    );
        begin
            @(negedge clk);

            init_we    = 1'b1;
            init_waddr = reg_id;
            init_wdata = value;

            @(posedge clk);
            #1;

            init_we    = 1'b0;
            init_waddr = '0;
            init_wdata = '0;

            $display(
                "SUCCESS: initialized R%0d = %0d",
                reg_id,
                value
            );
        end
    endtask

    task automatic finish_initialization;
        begin
            @(negedge clk);
            init_mode = 1'b0;

            $display(
                "SUCCESS: register-file initialization complete"
            );
        end
    endtask

    task automatic dispatch_instruction(
        input  logic [OP_W-1:0]       operation,
        input  logic [REG_ADDR_W-1:0] dest_reg,
        input  logic [REG_ADDR_W-1:0] src1_reg,
        input  logic [REG_ADDR_W-1:0] src2_reg,
        output logic [TAG_W-1:0]      allocated_tag
    );
        begin
            @(negedge clk);

            dispatch_valid    = 1'b1;
            dispatch_op       = operation;
            dispatch_src1_reg = src1_reg;
            dispatch_src2_reg = src2_reg;
            dispatch_dest_reg = dest_reg;

            #1;

            if (!dispatch_ready) begin
                $display(
                    "ERROR: backend cannot accept instruction op=%0d",
                    operation
                );
                $fatal;
            end

            if (
                operation == OP_MUL &&
                !mul_rs_dispatch_valid
            ) begin
                $display(
                    "ERROR: MUL was not routed to MUL RS"
                );
                $fatal;
            end

            if (
                operation != OP_MUL &&
                !alu_rs_dispatch_valid
            ) begin
                $display(
                    "ERROR: ALU operation was not routed to ALU RS"
                );
                $fatal;
            end

            allocated_tag = rob_alloc_tag;

            if (operation == OP_MUL) begin
                $display(
                    "DISPATCH: MUL R%0d, R%0d, R%0d -> ROB%0d",
                    dest_reg,
                    src1_reg,
                    src2_reg,
                    allocated_tag
                );
            end else begin
                $display(
                    "DISPATCH: ADD R%0d, R%0d, R%0d -> ROB%0d",
                    dest_reg,
                    src1_reg,
                    src2_reg,
                    allocated_tag
                );
            end

            @(posedge clk);
            #1;

            dispatch_valid    = 1'b0;
            dispatch_op       = '0;
            dispatch_src1_reg = '0;
            dispatch_src2_reg = '0;
            dispatch_dest_reg = '0;
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
                    "ERROR: expected CDB ROB%0d, got ROB%0d",
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
                    "ERROR: expected commit ROB%0d, got ROB%0d",
                    expected_tag,
                    rob_commit_tag
                );
                $fatal;
            end

            if (rob_commit_dest_reg !== expected_dest_reg) begin
                $display(
                    "ERROR: expected destination R%0d, got R%0d",
                    expected_dest_reg,
                    rob_commit_dest_reg
                );
                $fatal;
            end

            if (rob_commit_value !== expected_value) begin
                $display(
                    "ERROR: expected value %0d, got %0d",
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
                "SUCCESS: committed ROB%0d -> R%0d = %0d",
                expected_tag,
                expected_dest_reg,
                expected_value
            );
        end
    endtask

    task automatic expect_register(
        input logic [REG_ADDR_W-1:0] reg_id,
        input logic [XLEN-1:0]       expected_value
    );
        begin
            dispatch_src1_reg = reg_id;
            #1;

            if (rf_rdata1 !== expected_value) begin
                $display(
                    "ERROR: expected R%0d=%0d, got %0d",
                    reg_id,
                    expected_value,
                    rf_rdata1
                );
                $fatal;
            end

            $display(
                "SUCCESS: architectural R%0d = %0d",
                reg_id,
                rf_rdata1
            );
        end
    endtask

    task automatic expect_cdb_collision(
        input logic [TAG_W-1:0] mul_tag,
        input logic [TAG_W-1:0] add_tag
    );
        logic [TAG_W-1:0] held_mul_tag;
        logic [XLEN-1:0]  held_mul_value;

        begin
            // Wait until both functional units are simultaneously
            // presenting completed results.
            while (!(alu_result_valid && mul_result_valid)) begin
                @(posedge clk);
                #1;
            end

            $display(
                "INFO: observed simultaneous ALU and MUL results"
            );

            // ALU is source 0 and therefore wins.
            if (!alu_result_ready) begin
                $display(
                    "ERROR: ALU did not receive arbiter ready"
                );
                $fatal;
            end

            if (mul_result_ready) begin
                $display(
                    "ERROR: MUL incorrectly received arbiter ready"
                );
                $fatal;
            end

            if (
                cdb_valid !== 1'b1 ||
                cdb_tag   !== add_tag ||
                cdb_value !== 32'd15
            ) begin
                $display(
                    "ERROR: expected ALU ROB%0d=15 to win collision",
                    add_tag
                );
                $fatal;
            end

            // Save the losing MUL result.
            held_mul_tag   = mul_result_tag;
            held_mul_value = mul_result;

            if (held_mul_tag !== mul_tag) begin
                $display(
                    "ERROR: expected waiting MUL tag ROB%0d, got ROB%0d",
                    mul_tag,
                    held_mul_tag
                );
                $fatal;
            end

            if (held_mul_value !== 32'd20) begin
                $display(
                    "ERROR: expected waiting MUL value 20, got %0d",
                    held_mul_value
                );
                $fatal;
            end

            if (!mul_fu_busy) begin
                $display(
                    "ERROR: MUL FU should remain busy while result is blocked"
                );
                $fatal;
            end

            $display(
                "SUCCESS: ALU won collision and MUL was backpressured"
            );

            // The ALU result is accepted at the next rising edge.
            @(posedge clk);
            #1;

            // The multiplier must still present the same result after losing
            // arbitration.
            if (!mul_result_valid) begin
                $display(
                    "ERROR: MUL dropped result after losing arbitration"
                );
                $fatal;
            end

            if (mul_result_tag !== held_mul_tag) begin
                $display(
                    "ERROR: MUL tag changed while result was waiting"
                );
                $fatal;
            end

            if (mul_result !== held_mul_value) begin
                $display(
                    "ERROR: MUL value changed while result was waiting"
                );
                $fatal;
            end

            // With the ALU result gone, MUL should now win.
            if (!mul_result_ready) begin
                $display(
                    "ERROR: MUL did not receive ready after ALU completed"
                );
                $fatal;
            end

            if (
                cdb_valid !== 1'b1 ||
                cdb_tag   !== mul_tag ||
                cdb_value !== 32'd20
            ) begin
                $display(
                    "ERROR: expected held MUL ROB%0d=20 on CDB",
                    mul_tag
                );
                $fatal;
            end

            $display(
                "SUCCESS: MUL held stable and broadcast on following cycle"
            );

            // Allow the multiplier result handshake to complete.
            @(posedge clk);
            #1;
        end
    endtask

    // ----------------------------------------------------------------
    // Test sequence
    // ----------------------------------------------------------------

    initial begin
        logic [TAG_W-1:0] mul_tag;
        logic [TAG_W-1:0] add_tag;

        $dumpfile("backend_cdb_collision_tb.vcd");
        $dumpvars(0, backend_cdb_collision_tb);

        $display(
            "INFO: CDB collision test, ALU latency=%0d, MUL latency=%0d",
            ALU_LATENCY,
            MUL_LATENCY
        );

        reset_dut();

        // Initial architectural state:
        //
        // R2 = 4
        // R3 = 5
        // R5 = 7
        // R6 = 8
        initialize_register(3'd2, 32'd4);
        initialize_register(3'd3, 32'd5);
        initialize_register(3'd5, 32'd7);
        initialize_register(3'd6, 32'd8);

        finish_initialization();

        // Older multiply:
        //
        // I0: MUL R1, R2, R3
        //     ROB0 = 4 * 5 = 20
        dispatch_instruction(
            OP_MUL,
            3'd1,
            3'd2,
            3'd3,
            mul_tag
        );

        expected_mul_tag = mul_tag;

        // Younger ADD:
        //
        // I1: ADD R4, R5, R6
        //     ROB1 = 7 + 8 = 15
        dispatch_instruction(
            OP_ADD,
            3'd4,
            3'd5,
            3'd6,
            add_tag
        );

        expected_add_tag = add_tag;

        // Both results should become valid together.
        //
        // Fixed priority:
        //   source 0 = ALU
        //   source 1 = MUL
        //
        // Therefore ALU broadcasts first and MUL waits.
        expect_cdb_collision(
            mul_tag,
            add_tag
        );

        if (!collision_seen) begin
            $display(
                "ERROR: simultaneous result collision was never observed"
            );
            $fatal;
        end

        if (!alu_broadcast_seen) begin
            $display(
                "ERROR: ALU result was never broadcast"
            );
            $fatal;
        end

        if (!mul_broadcast_seen) begin
            $display(
                "ERROR: MUL result was never broadcast"
            );
            $fatal;
        end

        // The multiply is older even though the ADD won the CDB first.
        // Commit must remain in ROB order.
        commit_expect(
            mul_tag,
            3'd1,
            32'd20
        );

        commit_expect(
            add_tag,
            3'd4,
            32'd15
        );

        expect_register(
            3'd1,
            32'd20
        );

        expect_register(
            3'd4,
            32'd15
        );

        if (rob_count !== '0) begin
            $display(
                "ERROR: expected empty ROB, got count %0d",
                rob_count
            );
            $fatal;
        end

        if (alu_rs_count !== '0) begin
            $display(
                "ERROR: expected empty ALU RS, got count %0d",
                alu_rs_count
            );
            $fatal;
        end

        if (mul_rs_count !== '0) begin
            $display(
                "ERROR: expected empty MUL RS, got count %0d",
                mul_rs_count
            );
            $fatal;
        end

        $display(
            "BACKEND CDB COLLISION TEST PASSED"
        );

        $finish;
    end

endmodule

`timescale 1ns/1ps

module backend_rename_tb;

    localparam int NUM_ROB_ENTRIES = 4;
    localparam int NUM_RS_ENTRIES  = 4;
    localparam int NUM_REGS        = 8;

    localparam int XLEN       = 32;
    localparam int REG_ADDR_W = $clog2(NUM_REGS);
    localparam int TAG_W      = $clog2(NUM_ROB_ENTRIES);
    localparam int OP_W       = 4;
    localparam int FU_LATENCY = 3;

    localparam int ROB_COUNT_W = $clog2(NUM_ROB_ENTRIES + 1);
    localparam int RS_COUNT_W  = $clog2(NUM_RS_ENTRIES + 1);

    localparam logic [OP_W-1:0] OP_ADD = 4'd0;

    logic clk;
    logic rst_n;
    int unsigned cycle;

    // ----------------------------------------------------------------
    // Architectural register-file read ports
    // ----------------------------------------------------------------

    logic [REG_ADDR_W-1:0] rf_raddr1;
    logic [REG_ADDR_W-1:0] rf_raddr2;
    logic [XLEN-1:0]       rf_rdata1;
    logic [XLEN-1:0]       rf_rdata2;

    // Register-file write port
    logic                  rf_we;
    logic [REG_ADDR_W-1:0] rf_waddr;
    logic [XLEN-1:0]       rf_wdata;

    // Testbench initialization write port
    logic                  init_mode;
    logic                  init_we;
    logic [REG_ADDR_W-1:0] init_waddr;
    logic [XLEN-1:0]       init_wdata;

    // ----------------------------------------------------------------
    // Rename-table source lookup
    // ----------------------------------------------------------------

    logic [REG_ADDR_W-1:0] rename_src1_reg;
    logic                  rename_src1_pending;
    logic [TAG_W-1:0]      rename_src1_tag;

    logic [REG_ADDR_W-1:0] rename_src2_reg;
    logic                  rename_src2_pending;
    logic [TAG_W-1:0]      rename_src2_tag;

    // Rename-table destination update
    logic                  rename_valid;
    logic [REG_ADDR_W-1:0] rename_dest_reg;
    logic [TAG_W-1:0]      rename_dest_tag;

    // Rename-table commit clear
    logic                  rename_commit_valid;
    logic [REG_ADDR_W-1:0] rename_commit_dest_reg;
    logic [TAG_W-1:0]      rename_commit_tag;

    // ----------------------------------------------------------------
    // ROB allocation
    // ----------------------------------------------------------------

    logic                  rob_alloc_valid;
    logic                  rob_alloc_ready;
    logic [REG_ADDR_W-1:0] rob_alloc_dest_reg;
    logic [TAG_W-1:0]      rob_alloc_tag;

    // ROB writeback
    logic                  rob_wb_valid;
    logic [TAG_W-1:0]      rob_wb_tag;
    logic [XLEN-1:0]       rob_wb_value;

    // ROB commit
    logic                  rob_commit_valid;
    logic                  rob_commit_ready;
    logic [REG_ADDR_W-1:0] rob_commit_dest_reg;
    logic [XLEN-1:0]       rob_commit_value;
    logic [TAG_W-1:0]      rob_commit_tag;

    logic                  rob_commit_fire;
    logic [ROB_COUNT_W-1:0] rob_count;

    // ----------------------------------------------------------------
    // Reservation-station dispatch
    // ----------------------------------------------------------------

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

    // Reservation-station issue
    logic             rs_issue_valid;
    logic             rs_issue_ready;
    logic [OP_W-1:0]  rs_issue_op;
    logic [XLEN-1:0]  rs_issue_src1_value;
    logic [XLEN-1:0]  rs_issue_src2_value;
    logic [TAG_W-1:0] rs_issue_dest_tag;

    logic [RS_COUNT_W-1:0] rs_count;

    // ----------------------------------------------------------------
    // Functional unit
    // ----------------------------------------------------------------

    logic             fu_start;
    logic             fu_busy;
    logic             fu_result_valid;
    logic [XLEN-1:0]  fu_result;
    logic [TAG_W-1:0] fu_result_tag;

    // ----------------------------------------------------------------
    // Common data bus
    // ----------------------------------------------------------------

    logic             cdb_valid;
    logic [TAG_W-1:0] cdb_tag;
    logic [XLEN-1:0]  cdb_value;

    // ----------------------------------------------------------------
    // Module instances
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

    // ----------------------------------------------------------------
    // Backend wiring
    // ----------------------------------------------------------------

    // RS issues when the functional unit is available.
    assign rs_issue_ready = !fu_busy;
    assign fu_start       = rs_issue_valid && rs_issue_ready;

    // CDB writes completed results into the ROB.
    assign rob_wb_valid = cdb_valid;
    assign rob_wb_tag   = cdb_tag;
    assign rob_wb_value = cdb_value;

    // A commit occurs only when both valid and ready are asserted.
    assign rob_commit_fire = rob_commit_valid && rob_commit_ready;

    // Committing an instruction clears the matching rename mapping.
    assign rename_commit_valid    = rob_commit_fire;
    assign rename_commit_dest_reg = rob_commit_dest_reg;
    assign rename_commit_tag      = rob_commit_tag;

    // During initialization, the testbench controls the register-file
    // write port. Afterwards, ROB commit controls it.
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
    // Clock
    // ----------------------------------------------------------------

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            cycle = 0;
        end else begin
            cycle = cycle + 1;

            if (rs_issue_valid && rs_issue_ready) begin
                $display(
                    "[CYCLE %0d] ISSUE ROB%0d: %0d + %0d",
                    cycle,
                    rs_issue_dest_tag,
                    rs_issue_src1_value,
                    rs_issue_src2_value
                );
            end

            if (cdb_valid) begin
                $display(
                    "[CYCLE %0d] CDB ROB%0d = %0d",
                    cycle,
                    cdb_tag,
                    cdb_value
                );
            end

            if (rob_commit_valid && rob_commit_ready) begin
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
            rst_n = 1'b0;

            init_mode  = 1'b1;
            init_we    = 1'b0;
            init_waddr = '0;
            init_wdata = '0;

            rf_raddr1 = '0;
            rf_raddr2 = '0;

            rename_src1_reg = '0;
            rename_src2_reg = '0;

            rename_valid    = 1'b0;
            rename_dest_reg = '0;
            rename_dest_tag = '0;

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
                $display(
                    "ERROR: ROB count should be 0 after reset, got %0d",
                    rob_count
                );
                $fatal;
            end

            if (rs_count !== '0) begin
                $display(
                    "ERROR: RS count should be 0 after reset, got %0d",
                    rs_count
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

            $display("SUCCESS: initialized R%0d = %0d", reg_id, value);
        end
    endtask

    task automatic finish_initialization;
        begin
            @(negedge clk);
            init_mode = 1'b0;

            $display("SUCCESS: register-file initialization complete");
        end
    endtask

    task automatic dispatch_add(
        input  logic [REG_ADDR_W-1:0] dest_reg,
        input  logic [REG_ADDR_W-1:0] src1_reg,
        input  logic [REG_ADDR_W-1:0] src2_reg,
        output logic [TAG_W-1:0]      allocated_tag
    );
        begin
            @(negedge clk);

            if (!rob_alloc_ready) begin
                $display("ERROR: ROB is full during dispatch");
                $fatal;
            end

            if (!rs_dispatch_ready) begin
                $display("ERROR: reservation station is full during dispatch");
                $fatal;
            end

            // Select architectural source registers.
            rf_raddr1 = src1_reg;
            rf_raddr2 = src2_reg;

            rename_src1_reg = src1_reg;
            rename_src2_reg = src2_reg;

            // Allow combinational regfile and rename lookups to settle.
            #1;

            // The ROB's current tail is the destination tag for this
            // instruction. Capture it before the allocation edge.
            allocated_tag = rob_alloc_tag;

            rob_alloc_valid    = 1'b1;
            rob_alloc_dest_reg = dest_reg;

            rename_valid    = 1'b1;
            rename_dest_reg = dest_reg;
            rename_dest_tag = allocated_tag;

            rs_dispatch_valid    = 1'b1;
            rs_dispatch_op       = OP_ADD;
            rs_dispatch_dest_tag = allocated_tag;

            // If src1 is pending, send its producer tag to the RS.
            // Otherwise, send its committed register-file value.
            if (rename_src1_pending) begin
                rs_dispatch_src1_ready = 1'b0;
                rs_dispatch_src1_value = '0;
                rs_dispatch_src1_tag   = rename_src1_tag;
            end else begin
                rs_dispatch_src1_ready = 1'b1;
                rs_dispatch_src1_value = rf_rdata1;
                rs_dispatch_src1_tag   = '0;
            end

            // Do the same lookup/selection for src2.
            if (rename_src2_pending) begin
                rs_dispatch_src2_ready = 1'b0;
                rs_dispatch_src2_value = '0;
                rs_dispatch_src2_tag   = rename_src2_tag;
            end else begin
                rs_dispatch_src2_ready = 1'b1;
                rs_dispatch_src2_value = rf_rdata2;
                rs_dispatch_src2_tag   = '0;
            end

            $display(
                "DISPATCH: ADD R%0d, R%0d, R%0d -> ROB%0d",
                dest_reg,
                src1_reg,
                src2_reg,
                allocated_tag
            );

            if (rename_src1_pending) begin
                $display(
                    "          src1 R%0d waits for ROB%0d",
                    src1_reg,
                    rename_src1_tag
                );
            end else begin
                $display(
                    "          src1 R%0d ready with value %0d",
                    src1_reg,
                    rf_rdata1
                );
            end

            if (rename_src2_pending) begin
                $display(
                    "          src2 R%0d waits for ROB%0d",
                    src2_reg,
                    rename_src2_tag
                );
            end else begin
                $display(
                    "          src2 R%0d ready with value %0d",
                    src2_reg,
                    rf_rdata2
                );
            end

            @(posedge clk);
            #1;

            rob_alloc_valid    = 1'b0;
            rob_alloc_dest_reg = '0;

            rename_valid    = 1'b0;
            rename_dest_reg = '0;
            rename_dest_tag = '0;

            rs_dispatch_valid      = 1'b0;
            rs_dispatch_op         = '0;
            rs_dispatch_src1_ready = 1'b0;
            rs_dispatch_src1_value = '0;
            rs_dispatch_src1_tag   = '0;
            rs_dispatch_src2_ready = 1'b0;
            rs_dispatch_src2_value = '0;
            rs_dispatch_src2_tag   = '0;
            rs_dispatch_dest_tag   = '0;
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

            // Move beyond this one-cycle result-valid pulse.
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
                    "ERROR: expected commit destination R%0d, got R%0d",
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

            // This causes the ROB to pop, writes the value to the
            // architectural regfile, and clears the rename mapping.
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
            rf_raddr1 = reg_id;
            #1;

            if (rf_rdata1 !== expected_value) begin
                $display(
                    "ERROR: expected R%0d = %0d, got %0d",
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

    task automatic expect_not_pending(
        input logic [REG_ADDR_W-1:0] reg_id
    );
        begin
            rename_src1_reg = reg_id;
            #1;

            if (rename_src1_pending) begin
                $display(
                    "ERROR: expected R%0d rename mapping to be cleared",
                    reg_id
                );
                $fatal;
            end

            $display("SUCCESS: R%0d is no longer pending", reg_id);
        end
    endtask

    // ----------------------------------------------------------------
    // Test sequence
    // ----------------------------------------------------------------

    initial begin
        logic [TAG_W-1:0] tag0;
        logic [TAG_W-1:0] tag1;

        $dumpfile("backend_rename_tb.vcd");
        $dumpvars(0, backend_rename_tb);

        $display("INFO: FU latency = %0d cycles", FU_LATENCY);

        reset_dut();

        // Initial committed architectural state:
        //
        // R2 = 10
        // R3 = 20
        // R5 = 5
        initialize_register(3'd2, 32'd10);
        initialize_register(3'd3, 32'd20);
        initialize_register(3'd5, 32'd5);

        finish_initialization();

        // I0: ADD R1, R2, R3
        //
        // Both sources should come directly from the register file.
        // The destination should be renamed to ROB0.
        dispatch_add(3'd1, 3'd2, 3'd3, tag0);

        // I1: ADD R4, R1, R5
        //
        // R1 should be detected as pending on tag0.
        // R5 should come directly from the register file.
        dispatch_add(3'd4, 3'd1, 3'd5, tag1);

        // I0 calculates 10 + 20 = 30.
        // Its CDB broadcast should wake I1's R1 operand.
        wait_for_cdb_result(tag0, 32'd30);

        // I1 then calculates 30 + 5 = 35.
        wait_for_cdb_result(tag1, 32'd35);

        // Results must commit in program order.
        commit_expect(tag0, 3'd1, 32'd30);
        commit_expect(tag1, 3'd4, 32'd35);

        // Verify committed architectural state.
        expect_register(3'd1, 32'd30);
        expect_register(3'd4, 32'd35);

        // Commit should have cleared both current rename mappings.
        expect_not_pending(3'd1);
        expect_not_pending(3'd4);

        if (rob_count !== '0) begin
            $display(
                "ERROR: expected ROB count 0 after commits, got %0d",
                rob_count
            );
            $fatal;
        end

        if (rs_count !== '0) begin
            $display(
                "ERROR: expected RS count 0 after issues, got %0d",
                rs_count
            );
            $fatal;
        end

        $display("BACKEND RENAME INTEGRATION TEST PASSED");
        $finish;
    end

endmodule

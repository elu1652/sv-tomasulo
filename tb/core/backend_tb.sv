`timescale 1ns/1ps

module backend_tb;

    // ============================================================
    // Configuration
    // ============================================================

    localparam int NUM_ROB_ENTRIES    = 4;
    localparam int NUM_ALU_RS_ENTRIES = 2;
    localparam int NUM_MUL_RS_ENTRIES = 2;
    localparam int NUM_REGS           = 8;

    localparam int XLEN        = 32;
    localparam int OP_W        = 4;
    localparam int ALU_LATENCY = 1;
    localparam int MUL_LATENCY = 3;

    localparam int REG_ADDR_W =
        (NUM_REGS <= 1) ? 1 : $clog2(NUM_REGS);

    localparam int TAG_W =
        (NUM_ROB_ENTRIES <= 1) ? 1 : $clog2(NUM_ROB_ENTRIES);

    localparam int ROB_COUNT_W =
        $clog2(NUM_ROB_ENTRIES + 1);

    localparam int ALU_RS_COUNT_W =
        $clog2(NUM_ALU_RS_ENTRIES + 1);

    localparam int MUL_RS_COUNT_W =
        $clog2(NUM_MUL_RS_ENTRIES + 1);

    localparam logic [OP_W-1:0] OP_ADD = 4'd0;
    localparam logic [OP_W-1:0] OP_MUL = 4'd5;

    // ============================================================
    // Clock and reset
    // ============================================================

    logic clk;
    logic rst_n;

    int unsigned cycle;

    // ============================================================
    // Dispatch interface
    // ============================================================

    logic                  dispatch_valid;
    logic                  dispatch_ready;
    logic [OP_W-1:0]       dispatch_op;
    logic [REG_ADDR_W-1:0] dispatch_src1_reg;
    logic [REG_ADDR_W-1:0] dispatch_src2_reg;
    logic [REG_ADDR_W-1:0] dispatch_dest_reg;

    // ============================================================
    // Register initialization
    // ============================================================

    logic                  init_we;
    logic [REG_ADDR_W-1:0] init_waddr;
    logic [XLEN-1:0]       init_wdata;

    // ============================================================
    // Commit observation
    // ============================================================

    logic                  commit_valid;
    logic [REG_ADDR_W-1:0] commit_dest_reg;
    logic [XLEN-1:0]       commit_value;
    logic [TAG_W-1:0]      commit_tag;

    // ============================================================
    // Debug outputs
    // ============================================================

    logic [ROB_COUNT_W-1:0]    rob_count;
    logic [ALU_RS_COUNT_W-1:0] alu_rs_count;
    logic [MUL_RS_COUNT_W-1:0] mul_rs_count;

    logic              cdb_valid;
    logic [TAG_W-1:0]  cdb_tag;
    logic [XLEN-1:0]   cdb_value;

    logic alu_result_valid_debug;
    logic mul_result_valid_debug;
    logic alu_result_ready_debug;
    logic mul_result_ready_debug;

    // ============================================================
    // Test status
    // ============================================================

    logic saw_collision;
    logic saw_alu_cdb;
    logic saw_mul_cdb;
    logic saw_mul_commit;
    logic saw_add_commit;

    logic waiting_for_held_mul;

    int unsigned commit_count;

    // ============================================================
    // DUT
    // ============================================================

    backend #(
        .NUM_ROB_ENTRIES(NUM_ROB_ENTRIES),
        .NUM_ALU_RS_ENTRIES(NUM_ALU_RS_ENTRIES),
        .NUM_MUL_RS_ENTRIES(NUM_MUL_RS_ENTRIES),
        .NUM_REGS(NUM_REGS),

        .XLEN(XLEN),
        .OP_W(OP_W),
        .ALU_LATENCY(ALU_LATENCY),
        .MUL_LATENCY(MUL_LATENCY)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .dispatch_valid(dispatch_valid),
        .dispatch_ready(dispatch_ready),
        .dispatch_op(dispatch_op),
        .dispatch_src1_reg(dispatch_src1_reg),
        .dispatch_src2_reg(dispatch_src2_reg),
        .dispatch_dest_reg(dispatch_dest_reg),

        .init_we(init_we),
        .init_waddr(init_waddr),
        .init_wdata(init_wdata),

        .commit_valid(commit_valid),
        .commit_dest_reg(commit_dest_reg),
        .commit_value(commit_value),
        .commit_tag(commit_tag),

        .rob_count(rob_count),
        .alu_rs_count(alu_rs_count),
        .mul_rs_count(mul_rs_count),

        .cdb_valid(cdb_valid),
        .cdb_tag(cdb_tag),
        .cdb_value(cdb_value),

        .alu_result_valid_debug(alu_result_valid_debug),
        .mul_result_valid_debug(mul_result_valid_debug),
        .alu_result_ready_debug(alu_result_ready_debug),
        .mul_result_ready_debug(mul_result_ready_debug)
    );

    // ============================================================
    // Clock generation
    // ============================================================

    initial begin
        clk = 1'b0;

        forever begin
            #5 clk = ~clk;
        end
    end

    // ============================================================
    // Cycle counter and event tracing
    // ============================================================

    always @(posedge clk) begin
        if (!rst_n) begin
            cycle <= 0;
        end else begin
            cycle <= cycle + 1;
        end

        #1;

        if (alu_result_valid_debug && mul_result_valid_debug) begin
            $display(
                "[CYCLE %0d] CDB COLLISION: ALU and MUL both valid",
                cycle
            );

            if (!alu_result_ready_debug) begin
                $fatal(
                    1,
                    "ALU should win fixed-priority arbitration"
                );
            end

            if (mul_result_ready_debug) begin
                $fatal(
                    1,
                    "MUL should be backpressured during collision"
                );
            end

            if (
                !cdb_valid ||
                cdb_tag != TAG_W'(1) ||
                cdb_value != XLEN'(15)
            ) begin
                $fatal(
                    1,
                    "Collision CDB must carry ALU ROB1 = 15"
                );
            end

            saw_collision        = 1'b1;
            waiting_for_held_mul = 1'b1;
        end

        if (cdb_valid) begin
            $display(
                "[CYCLE %0d] CDB ROB%0d = %0d",
                cycle,
                cdb_tag,
                cdb_value
            );

            // ALU wins the collision and broadcasts ROB1 = 15 first.
            if (
                cdb_tag == TAG_W'(1) &&
                cdb_value == XLEN'(15)
            ) begin
                saw_alu_cdb = 1'b1;
            end

            // The backpressured MUL result must broadcast afterward.
            if (
                cdb_tag == TAG_W'(0) &&
                cdb_value == XLEN'(20)
            ) begin
                if (!waiting_for_held_mul) begin
                    $fatal(
                        1,
                        "MUL broadcast occurred without an observed collision"
                    );
                end

                saw_mul_cdb          = 1'b1;
                waiting_for_held_mul = 1'b0;
            end
        end

        if (commit_valid) begin
            $display(
                "[CYCLE %0d] COMMIT ROB%0d: R%0d = %0d",
                cycle,
                commit_tag,
                commit_dest_reg,
                commit_value
            );

            commit_count = commit_count + 1;

            if (commit_count == 1) begin
                if (
                    commit_tag != TAG_W'(0) ||
                    commit_dest_reg != REG_ADDR_W'(1) ||
                    commit_value != XLEN'(20)
                ) begin
                    $fatal(
                        1,
                        "First commit must be ROB0: R1 = 20"
                    );
                end

                saw_mul_commit = 1'b1;
            end

            if (commit_count == 2) begin
                if (
                    commit_tag != TAG_W'(1) ||
                    commit_dest_reg != REG_ADDR_W'(4) ||
                    commit_value != XLEN'(15)
                ) begin
                    $fatal(
                        1,
                        "Second commit must be ROB1: R4 = 15"
                    );
                end

                saw_add_commit = 1'b1;
            end
        end
    end

    // ============================================================
    // Register initialization task
    // ============================================================

    task automatic initialize_register(
        input logic [REG_ADDR_W-1:0] reg_index,
        input logic [XLEN-1:0]       value
    );
        begin
            @(negedge clk);

            init_we    = 1'b1;
            init_waddr = reg_index;
            init_wdata = value;

            @(negedge clk);

            init_we    = 1'b0;
            init_waddr = '0;
            init_wdata = '0;
        end
    endtask

    // ============================================================
    // Dispatch task
    // ============================================================

    task automatic dispatch_instruction(
        input logic [OP_W-1:0]       op,
        input logic [REG_ADDR_W-1:0] src1_reg,
        input logic [REG_ADDR_W-1:0] src2_reg,
        input logic [REG_ADDR_W-1:0] dest_reg
    );
        begin
            @(negedge clk);

            dispatch_valid    = 1'b1;
            dispatch_op       = op;
            dispatch_src1_reg = src1_reg;
            dispatch_src2_reg = src2_reg;
            dispatch_dest_reg = dest_reg;

            while (!dispatch_ready) begin
                @(negedge clk);
            end

            // dispatch_valid and dispatch_ready are both high during
            // the following rising edge, so dispatch occurs there.
            @(negedge clk);

            dispatch_valid    = 1'b0;
            dispatch_op       = '0;
            dispatch_src1_reg = '0;
            dispatch_src2_reg = '0;
            dispatch_dest_reg = '0;
        end
    endtask

    // ============================================================
    // Test sequence
    // ============================================================

    initial begin
        $dumpfile("waves/backend_tb.vcd");
        $dumpvars(0, backend_tb);

        rst_n = 1'b0;

        dispatch_valid    = 1'b0;
        dispatch_op       = '0;
        dispatch_src1_reg = '0;
        dispatch_src2_reg = '0;
        dispatch_dest_reg = '0;

        init_we    = 1'b0;
        init_waddr = '0;
        init_wdata = '0;

        saw_collision        = 1'b0;
        saw_alu_cdb          = 1'b0;
        saw_mul_cdb          = 1'b0;
        saw_mul_commit       = 1'b0;
        saw_add_commit       = 1'b0;
        waiting_for_held_mul = 1'b0;

        commit_count = 0;

        // Hold reset active for two rising edges.
        repeat (2) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        // Architectural starting state:
        initialize_register(REG_ADDR_W'(2), XLEN'(4));
        initialize_register(REG_ADDR_W'(3), XLEN'(5));
        initialize_register(REG_ADDR_W'(5), XLEN'(7));
        initialize_register(REG_ADDR_W'(6), XLEN'(8));

        // I0: MUL R1, R2, R3
        dispatch_instruction(
            OP_MUL,
            REG_ADDR_W'(2),
            REG_ADDR_W'(3),
            REG_ADDR_W'(1)
        );

        // I1: ADD R4, R5, R6
        dispatch_instruction(
            OP_ADD,
            REG_ADDR_W'(5),
            REG_ADDR_W'(6),
            REG_ADDR_W'(4)
        );

        // Allow enough time for dispatch, issue, execution,
        // CDB writeback, and commit.
        repeat (30) @(posedge clk);
        #1;

        if (!saw_collision) begin
            $fatal(
                1,
                "Expected simultaneous ALU and MUL result-valid collision"
            );
        end

        if (!saw_alu_cdb) begin
            $fatal(
                1,
                "Expected ALU ROB1 = 15 to win the collision"
            );
        end

        if (!saw_mul_cdb) begin
            $fatal(
                1,
                "Expected held MUL ROB0 = 20 to broadcast later"
            );
        end

        if (waiting_for_held_mul) begin
            $fatal(
                1,
                "MUL result remained pending after collision"
            );
        end

        if (!saw_mul_commit || !saw_add_commit) begin
            $fatal(
                1,
                "Expected both instructions to commit"
            );
        end

        if (commit_count != 2) begin
            $fatal(
                1,
                "Expected exactly 2 commits, observed %0d",
                commit_count
            );
        end

        $display("backend_tb PASSED");
        $finish;
    end

endmodule

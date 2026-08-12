`timescale 1ns/1ps

module backend_tb;

    // ============================================================
    // Configuration and operation encodings
    // ============================================================

    localparam int NUM_ROB_ENTRIES    = 4;
    localparam int NUM_ALU_RS_ENTRIES = 2;
    localparam int NUM_MUL_RS_ENTRIES = 2;
    localparam int NUM_REGS           = 8;
    localparam int XLEN                = 32;
    localparam int OP_W                = 4;
    localparam int REG_ADDR_W          = $clog2(NUM_REGS);
    localparam int TAG_W               = $clog2(NUM_ROB_ENTRIES);
    localparam int ROB_COUNT_W         = $clog2(NUM_ROB_ENTRIES + 1);
    localparam int ALU_RS_COUNT_W      = $clog2(NUM_ALU_RS_ENTRIES + 1);
    localparam int MUL_RS_COUNT_W      = $clog2(NUM_MUL_RS_ENTRIES + 1);
    localparam int MAX_EVENTS          = 16;
    localparam int MAX_WAIT_CYCLES     = 120;

    localparam logic [OP_W-1:0] OP_ADD = 4'd0;
    localparam logic [OP_W-1:0] OP_MUL = 4'd5;

    // ============================================================
    // Scenario identifiers
    // ============================================================

    localparam int SCENARIO_NONE          = 0;
    localparam int SCENARIO_BASIC         = 1;
    localparam int SCENARIO_SAME_FU       = 2;
    localparam int SCENARIO_OOO           = 3;
    localparam int SCENARIO_CROSS_FU      = 4;
    localparam int SCENARIO_COLLISION     = 5;
    localparam int SCENARIO_WAW           = 6;
    localparam int SCENARIO_COMMIT_RENAME = 7;
    localparam int SCENARIO_ROB_FULL      = 8;
    localparam int SCENARIO_RS_BACKPRESSURE = 9;
    localparam int SCENARIO_ROB_WRAPAROUND  = 10;
    localparam int SCENARIO_RESET_IN_FLIGHT = 11;

    // ============================================================
    // Clock
    // ============================================================

    logic clk;

    // ============================================================
    // Main DUT interface (ALU latency 1, MUL latency 5)
    // ============================================================

    logic main_rst_n;

    logic main_dispatch_valid;
    logic main_dispatch_ready;
    logic [OP_W-1:0] main_dispatch_op;
    logic [REG_ADDR_W-1:0] main_dispatch_src1_reg;
    logic [REG_ADDR_W-1:0] main_dispatch_src2_reg;
    logic [REG_ADDR_W-1:0] main_dispatch_dest_reg;

    logic main_init_we;
    logic [REG_ADDR_W-1:0] main_init_waddr;
    logic [XLEN-1:0] main_init_wdata;

    logic main_commit_valid;
    logic [REG_ADDR_W-1:0] main_commit_dest_reg;
    logic [XLEN-1:0] main_commit_value;
    logic [TAG_W-1:0] main_commit_tag;

    logic [ROB_COUNT_W-1:0] main_rob_count;
    logic [ALU_RS_COUNT_W-1:0] main_alu_rs_count;
    logic [MUL_RS_COUNT_W-1:0] main_mul_rs_count;

    logic main_cdb_valid;
    logic [TAG_W-1:0] main_cdb_tag;
    logic [XLEN-1:0] main_cdb_value;

    /* verilator lint_off UNUSEDSIGNAL */
    logic main_alu_result_valid_debug;
    logic main_mul_result_valid_debug;
    logic main_alu_result_ready_debug;
    logic main_mul_result_ready_debug;
    /* verilator lint_on UNUSEDSIGNAL */

    // ============================================================
    // Collision DUT interface (ALU latency 1, MUL latency 3)
    // ============================================================

    logic collision_rst_n;

    logic collision_dispatch_valid;
    logic collision_dispatch_ready;
    logic [OP_W-1:0] collision_dispatch_op;
    logic [REG_ADDR_W-1:0] collision_dispatch_src1_reg;
    logic [REG_ADDR_W-1:0] collision_dispatch_src2_reg;
    logic [REG_ADDR_W-1:0] collision_dispatch_dest_reg;

    logic collision_init_we;
    logic [REG_ADDR_W-1:0] collision_init_waddr;
    logic [XLEN-1:0] collision_init_wdata;

    logic collision_commit_valid;
    logic [REG_ADDR_W-1:0] collision_commit_dest_reg;
    logic [XLEN-1:0] collision_commit_value;
    logic [TAG_W-1:0] collision_commit_tag;

    logic [ROB_COUNT_W-1:0] collision_rob_count;
    logic [ALU_RS_COUNT_W-1:0] collision_alu_rs_count;
    logic [MUL_RS_COUNT_W-1:0] collision_mul_rs_count;

    logic collision_cdb_valid;
    logic [TAG_W-1:0] collision_cdb_tag;
    logic [XLEN-1:0] collision_cdb_value;

    logic collision_alu_result_valid_debug;
    logic collision_mul_result_valid_debug;
    logic collision_alu_result_ready_debug;
    logic collision_mul_result_ready_debug;

    // ============================================================
    // Shared event capture and scenario state
    // ============================================================

    int scenario_id;
    int unsigned cycle;
    int unsigned broadcast_count;
    int unsigned commit_count;
    int unsigned collision_cycle;

    logic [TAG_W-1:0] cdb_tags [0:MAX_EVENTS-1];
    logic [XLEN-1:0] cdb_values [0:MAX_EVENTS-1];

    logic [TAG_W-1:0] commit_tags [0:MAX_EVENTS-1];
    logic [REG_ADDR_W-1:0] commit_dest_regs [0:MAX_EVENTS-1];
    logic [XLEN-1:0] commit_values [0:MAX_EVENTS-1];

    logic saw_collision;
    logic waiting_for_held_mul;
    logic saw_rob1_waw_broadcast;

    logic saw_same_cycle_commit_rename;

    // ============================================================
    // DUT instantiations
    // ============================================================

    backend #(
        .NUM_ROB_ENTRIES(NUM_ROB_ENTRIES),
        .NUM_ALU_RS_ENTRIES(NUM_ALU_RS_ENTRIES),
        .NUM_MUL_RS_ENTRIES(NUM_MUL_RS_ENTRIES),
        .NUM_REGS(NUM_REGS),
        .XLEN(XLEN),
        .OP_W(OP_W),
        .ALU_LATENCY(1),
        .MUL_LATENCY(5)
    ) dut_main (
        .clk(clk),
        .rst_n(main_rst_n),

        .dispatch_valid(main_dispatch_valid),
        .dispatch_ready(main_dispatch_ready),
        .dispatch_op(main_dispatch_op),
        .dispatch_src1_reg(main_dispatch_src1_reg),
        .dispatch_src2_reg(main_dispatch_src2_reg),
        .dispatch_dest_reg(main_dispatch_dest_reg),

        .init_we(main_init_we),
        .init_waddr(main_init_waddr),
        .init_wdata(main_init_wdata),

        .commit_valid(main_commit_valid),
        .commit_dest_reg(main_commit_dest_reg),
        .commit_value(main_commit_value),
        .commit_tag(main_commit_tag),

        .rob_count(main_rob_count),
        .alu_rs_count(main_alu_rs_count),
        .mul_rs_count(main_mul_rs_count),

        .cdb_valid(main_cdb_valid),
        .cdb_tag(main_cdb_tag),
        .cdb_value(main_cdb_value),

        .alu_result_valid_debug(main_alu_result_valid_debug),
        .mul_result_valid_debug(main_mul_result_valid_debug),
        .alu_result_ready_debug(main_alu_result_ready_debug),
        .mul_result_ready_debug(main_mul_result_ready_debug)
    );

    backend #(
        .NUM_ROB_ENTRIES(NUM_ROB_ENTRIES),
        .NUM_ALU_RS_ENTRIES(NUM_ALU_RS_ENTRIES),
        .NUM_MUL_RS_ENTRIES(NUM_MUL_RS_ENTRIES),
        .NUM_REGS(NUM_REGS),
        .XLEN(XLEN),
        .OP_W(OP_W),
        .ALU_LATENCY(1),
        .MUL_LATENCY(3)
    ) dut_collision (
        .clk(clk),
        .rst_n(collision_rst_n),

        .dispatch_valid(collision_dispatch_valid),
        .dispatch_ready(collision_dispatch_ready),
        .dispatch_op(collision_dispatch_op),
        .dispatch_src1_reg(collision_dispatch_src1_reg),
        .dispatch_src2_reg(collision_dispatch_src2_reg),
        .dispatch_dest_reg(collision_dispatch_dest_reg),

        .init_we(collision_init_we),
        .init_waddr(collision_init_waddr),
        .init_wdata(collision_init_wdata),

        .commit_valid(collision_commit_valid),
        .commit_dest_reg(collision_commit_dest_reg),
        .commit_value(collision_commit_value),
        .commit_tag(collision_commit_tag),

        .rob_count(collision_rob_count),
        .alu_rs_count(collision_alu_rs_count),
        .mul_rs_count(collision_mul_rs_count),

        .cdb_valid(collision_cdb_valid),
        .cdb_tag(collision_cdb_tag),
        .cdb_value(collision_cdb_value),

        .alu_result_valid_debug(collision_alu_result_valid_debug),
        .mul_result_valid_debug(collision_mul_result_valid_debug),
        .alu_result_ready_debug(collision_alu_result_ready_debug),
        .mul_result_ready_debug(collision_mul_result_ready_debug)
    );

    // ============================================================
    // Clock generation
    // ============================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // Input and reset helpers
    // ============================================================

    // Drives all main-DUT stimulus inputs inactive.
    task automatic clear_main_inputs;
        begin
            main_dispatch_valid    = 1'b0;
            main_dispatch_op       = '0;
            main_dispatch_src1_reg = '0;
            main_dispatch_src2_reg = '0;
            main_dispatch_dest_reg = '0;
            main_init_we           = 1'b0;
            main_init_waddr        = '0;
            main_init_wdata        = '0;
        end
    endtask

    // Drives all collision-DUT stimulus inputs inactive.
    task automatic clear_collision_inputs;
        begin
            collision_dispatch_valid    = 1'b0;
            collision_dispatch_op       = '0;
            collision_dispatch_src1_reg = '0;
            collision_dispatch_src2_reg = '0;
            collision_dispatch_dest_reg = '0;
            collision_init_we           = 1'b0;
            collision_init_waddr        = '0;
            collision_init_wdata        = '0;
        end
    endtask

    // Clears event captures and all scenario-specific state.
    task automatic clear_status;
        int i;

        begin
            cycle                  = 0;
            broadcast_count        = 0;
            commit_count           = 0;
            collision_cycle        = 0;
            saw_collision          = 1'b0;
            waiting_for_held_mul   = 1'b0;
            saw_rob1_waw_broadcast = 1'b0;

            saw_same_cycle_commit_rename = 1'b0;

            for (i = 0; i < MAX_EVENTS; i = i + 1) begin
                cdb_tags[i]         = '0;
                cdb_values[i]       = '0;
                commit_tags[i]      = '0;
                commit_dest_regs[i] = '0;
                commit_values[i]    = '0;
            end
        end
    endtask

    // Resets both DUTs, then enables only the DUT used by the scenario.
    task automatic reset_dut(input int next_scenario);
        begin
            scenario_id = SCENARIO_NONE;

            clear_main_inputs();
            clear_collision_inputs();

            main_rst_n      = 1'b0;
            collision_rst_n = 1'b0;

            clear_status();

            repeat (2) @(posedge clk);
            @(negedge clk);

            scenario_id = next_scenario;

            if (next_scenario == SCENARIO_COLLISION) begin
                collision_rst_n = 1'b1;
            end else begin
                main_rst_n = 1'b1;
            end
        end
    endtask

    // ============================================================
    // Stimulus helpers
    // ============================================================

    // Initializes one architectural register on the selected DUT.
    task automatic initialize_register(
        input logic use_collision_dut,
        input logic [REG_ADDR_W-1:0] reg_index,
        input logic [XLEN-1:0] value
    );
        begin
            @(negedge clk);

            if (use_collision_dut) begin
                collision_init_we    = 1'b1;
                collision_init_waddr = reg_index;
                collision_init_wdata = value;
            end else begin
                main_init_we    = 1'b1;
                main_init_waddr = reg_index;
                main_init_wdata = value;
            end

            @(negedge clk);

            if (use_collision_dut) begin
                collision_init_we    = 1'b0;
                collision_init_waddr = '0;
                collision_init_wdata = '0;
            end else begin
                main_init_we    = 1'b0;
                main_init_waddr = '0;
                main_init_wdata = '0;
            end
        end
    endtask

    // Dispatches one instruction and bounds the ready handshake wait.
    task automatic dispatch_instruction(
        input logic use_collision_dut,
        input logic [OP_W-1:0] op,
        input logic [REG_ADDR_W-1:0] src1_reg,
        input logic [REG_ADDR_W-1:0] src2_reg,
        input logic [REG_ADDR_W-1:0] dest_reg
    );
        int unsigned wait_cycles;

        begin
            @(negedge clk);

            if (use_collision_dut) begin
                collision_dispatch_valid    = 1'b1;
                collision_dispatch_op       = op;
                collision_dispatch_src1_reg = src1_reg;
                collision_dispatch_src2_reg = src2_reg;
                collision_dispatch_dest_reg = dest_reg;
            end else begin
                main_dispatch_valid    = 1'b1;
                main_dispatch_op       = op;
                main_dispatch_src1_reg = src1_reg;
                main_dispatch_src2_reg = src2_reg;
                main_dispatch_dest_reg = dest_reg;
            end

            wait_cycles = 0;
            while (
                (use_collision_dut
                    ? collision_dispatch_ready
                    : main_dispatch_ready) !== 1'b1 &&
                wait_cycles < 10
            ) begin
                @(negedge clk);
                wait_cycles = wait_cycles + 1;
            end

            if (
                (use_collision_dut
                    ? collision_dispatch_ready
                    : main_dispatch_ready) !== 1'b1
            ) begin
                $fatal(1, "Timed out waiting for dispatch_ready");
            end

            @(negedge clk);

            if (use_collision_dut) begin
                clear_collision_inputs();
            end else begin
                clear_main_inputs();
            end
        end
    endtask

    // Drives a main-DUT instruction for one known accepting edge. Unlike
    // dispatch_instruction, consecutive calls dispatch on consecutive cycles.
    task automatic drive_main_instruction(
        input logic [OP_W-1:0] op,
        input logic [REG_ADDR_W-1:0] src1_reg,
        input logic [REG_ADDR_W-1:0] src2_reg,
        input logic [REG_ADDR_W-1:0] dest_reg
    );
        logic ready_before_edge;

        begin
            @(negedge clk);
            main_dispatch_valid    = 1'b1;
            main_dispatch_op       = op;
            main_dispatch_src1_reg = src1_reg;
            main_dispatch_src2_reg = src2_reg;
            main_dispatch_dest_reg = dest_reg;
            #1;

            ready_before_edge = main_dispatch_ready;
            if (ready_before_edge !== 1'b1) begin
                $fatal(1, "Expected dispatch_ready before accepting edge");
            end

            @(posedge clk);
            #1;

            if (main_dispatch_valid !== 1'b1 || ready_before_edge !== 1'b1) begin
                $fatal(1, "Expected valid/ready dispatch handshake");
            end
        end
    endtask

    // Holds one instruction across an accepting-edge opportunity while ready
    // is low, proving that no ROB or RS insertion occurs on that edge.
    task automatic hold_instruction_and_expect_blocked(
        input logic [OP_W-1:0] op,
        input logic [REG_ADDR_W-1:0] src1_reg,
        input logic [REG_ADDR_W-1:0] src2_reg,
        input logic [REG_ADDR_W-1:0] dest_reg,
        input logic [ROB_COUNT_W-1:0] expected_rob_count,
        input logic [ALU_RS_COUNT_W-1:0] expected_alu_rs_count,
        input logic [MUL_RS_COUNT_W-1:0] expected_mul_rs_count,
        input string reason
    );
        int unsigned broadcasts_before;
        int unsigned commits_before;

        begin
            @(negedge clk);
            main_dispatch_valid    = 1'b1;
            main_dispatch_op       = op;
            main_dispatch_src1_reg = src1_reg;
            main_dispatch_src2_reg = src2_reg;
            main_dispatch_dest_reg = dest_reg;
            #1;

            if (main_dispatch_ready !== 1'b0) begin
                $fatal(1, "%s: expected dispatch_ready low", reason);
            end

            if (
                main_rob_count != expected_rob_count ||
                main_alu_rs_count != expected_alu_rs_count ||
                main_mul_rs_count != expected_mul_rs_count
            ) begin
                $fatal(
                    1,
                    "%s: wrong occupancy before blocked edge: ROB=%0d ALU_RS=%0d MUL_RS=%0d",
                    reason,
                    main_rob_count,
                    main_alu_rs_count,
                    main_mul_rs_count
                );
            end

            broadcasts_before = broadcast_count;
            commits_before    = commit_count;

            @(posedge clk);
            #1;

            if (
                main_rob_count != expected_rob_count ||
                main_alu_rs_count != expected_alu_rs_count ||
                main_mul_rs_count != expected_mul_rs_count
            ) begin
                $fatal(1, "%s: blocked dispatch changed occupancy", reason);
            end

            if (
                broadcast_count != broadcasts_before ||
                commit_count != commits_before
            ) begin
                $fatal(1, "%s: unexpected event during blocked interval", reason);
            end

            $display("[CYCLE %0d] %s", cycle, reason);

            @(negedge clk);
            clear_main_inputs();
        end
    endtask

    // Dispatches an instruction on the exact rising edge that an older
    // instruction commits. This directly tests commit cleanup versus a
    // new rename allocation to the same architectural register.
    task automatic dispatch_on_commit(
        input logic [OP_W-1:0] op,
        input logic [REG_ADDR_W-1:0] src1_reg,
        input logic [REG_ADDR_W-1:0] src2_reg,
        input logic [REG_ADDR_W-1:0] dest_reg,
        input int expected_commit_tag,
        input int expected_commit_dest,
        input int expected_commit_value
    );
        logic dispatch_was_ready;

        begin
            @(negedge clk);

            main_dispatch_valid    = 1'b1;
            main_dispatch_op       = op;
            main_dispatch_src1_reg = src1_reg;
            main_dispatch_src2_reg = src2_reg;
            main_dispatch_dest_reg = dest_reg;

            // dispatch_ready is combinational and must already be high
            // before the accepting rising edge.
            dispatch_was_ready = main_dispatch_ready;

            if (dispatch_was_ready !== 1'b1) begin
                $fatal(
                    1,
                    "Expected dispatch_ready before simultaneous commit/rename edge"
                );
            end

            // This is the edge on which both operations occur:
            //
            // 1. ROB0 commits R1.
            // 2. The newly dispatched instruction allocates ROB1 and
            //    installs the newer R1 -> ROB1 rename mapping.
            @(posedge clk);

            // Allow DUT nonblocking assignments and combinational outputs
            // to settle, matching the convention used by the event monitor.
            #1;

            if (main_dispatch_valid !== 1'b1) begin
                $fatal(
                    1,
                    "dispatch_valid was not held through the accepting edge"
                );
            end

            if (main_commit_valid !== 1'b1) begin
                $fatal(
                    1,
                    "Expected an older instruction to commit during dispatch"
                );
            end

            if (
                main_commit_tag != TAG_W'(expected_commit_tag) ||
                main_commit_dest_reg != REG_ADDR_W'(expected_commit_dest) ||
                main_commit_value != XLEN'(expected_commit_value)
            ) begin
                $fatal(
                    1,
                    "Wrong simultaneous commit: expected ROB%0d R%0d = %0d, got ROB%0d R%0d = %0d",
                    expected_commit_tag,
                    expected_commit_dest,
                    expected_commit_value,
                    main_commit_tag,
                    main_commit_dest_reg,
                    main_commit_value
                );
            end

            saw_same_cycle_commit_rename = 1'b1;

            @(negedge clk);
            clear_main_inputs();
        end
    endtask

    // Waits for an exact number of CDB broadcasts with a finite timeout.
    task automatic wait_for_broadcasts(input int expected_count);
        int unsigned wait_cycles;

        begin
            wait_cycles = 0;

            while (
                broadcast_count < expected_count &&
                wait_cycles < MAX_WAIT_CYCLES
            ) begin
                @(posedge clk);
                #2;
                wait_cycles = wait_cycles + 1;
            end

            if (broadcast_count != expected_count) begin
                $fatal(
                    1,
                    "Timed out waiting for %0d broadcasts; observed %0d",
                    expected_count,
                    broadcast_count
                );
            end
        end
    endtask

    // Waits for an exact commit count, then checks for late extra commits.
    task automatic wait_for_commits(input int expected_count);
        int unsigned wait_cycles;

        begin
            wait_cycles = 0;

            while (
                commit_count < expected_count &&
                wait_cycles < MAX_WAIT_CYCLES
            ) begin
                @(posedge clk);
                #2;
                wait_cycles = wait_cycles + 1;
            end

            if (commit_count != expected_count) begin
                $fatal(
                    1,
                    "Timed out waiting for %0d commits; observed %0d",
                    expected_count,
                    commit_count
                );
            end

            repeat (3) @(posedge clk);
            #2;

            if (commit_count != expected_count) begin
                $fatal(1, "Observed an unexpected extra commit");
            end
        end
    endtask

    // ============================================================
    // Event and final-state check helpers
    // ============================================================

    // Verifies that the selected backend has fully drained.
    task automatic check_backend_empty(input logic use_collision_dut);
        begin
            if (use_collision_dut) begin
                if (
                    collision_rob_count != '0 ||
                    collision_alu_rs_count != '0 ||
                    collision_mul_rs_count != '0
                ) begin
                    $fatal(
                        1,
                        "Collision backend not empty: ROB=%0d ALU_RS=%0d MUL_RS=%0d",
                        collision_rob_count,
                        collision_alu_rs_count,
                        collision_mul_rs_count
                    );
                end
            end else begin
                if (
                    main_rob_count != '0 ||
                    main_alu_rs_count != '0 ||
                    main_mul_rs_count != '0
                ) begin
                    $fatal(
                        1,
                        "Main backend not empty: ROB=%0d ALU_RS=%0d MUL_RS=%0d",
                        main_rob_count,
                        main_alu_rs_count,
                        main_mul_rs_count
                    );
                end
            end
        end
    endtask

    // Checks one captured CDB event against its exact tag and value.
    task automatic check_cdb_event(
        input int index,
        input int expected_tag,
        input int expected_value
    );
        begin
            if (
                cdb_tags[index] != TAG_W'(expected_tag) ||
                cdb_values[index] != XLEN'(expected_value)
            ) begin
                $fatal(
                    1,
                    "CDB event %0d: expected ROB%0d = %0d, got ROB%0d = %0d",
                    index,
                    expected_tag,
                    expected_value,
                    cdb_tags[index],
                    cdb_values[index]
                );
            end
        end
    endtask

    // Checks one captured commit event against its exact destination.
    task automatic check_commit_event(
        input int index,
        input int expected_tag,
        input int expected_dest,
        input int expected_value
    );
        begin
            if (
                commit_tags[index] != TAG_W'(expected_tag) ||
                commit_dest_regs[index] != REG_ADDR_W'(expected_dest) ||
                commit_values[index] != XLEN'(expected_value)
            ) begin
                $fatal(
                    1,
                    "Commit %0d: expected ROB%0d R%0d = %0d, got ROB%0d R%0d = %0d",
                    index,
                    expected_tag,
                    expected_dest,
                    expected_value,
                    commit_tags[index],
                    commit_dest_regs[index],
                    commit_values[index]
                );
            end
        end
    endtask

    // Prints a consistent section header for each scenario.
    task automatic print_header(input string name);
        begin
            $display("\n==================================================");
            $display("[TEST] %s", name);
            $display("==================================================");
        end
    endtask

    // ============================================================
    // Scenario tests
    // ============================================================

    // Proves a single independent ADD executes, broadcasts, commits,
    // and leaves all reusable-backend structures empty.
    task automatic test_basic;
        begin
            print_header("Basic execution");
            reset_dut(SCENARIO_BASIC);
            initialize_register(1'b0, REG_ADDR_W'(2), XLEN'(10));
            initialize_register(1'b0, REG_ADDR_W'(3), XLEN'(20));

            dispatch_instruction(
                1'b0,
                OP_ADD,
                REG_ADDR_W'(2),
                REG_ADDR_W'(3),
                REG_ADDR_W'(1)
            );

            wait_for_commits(1);

            if (broadcast_count != 1) begin
                $fatal(1, "Expected exactly 1 broadcast, observed %0d", broadcast_count);
            end

            check_cdb_event(0, 0, 30);
            check_commit_event(0, 0, 1, 30);
            check_backend_empty(1'b0);

            $display("[PASS] Basic execution");
        end
    endtask

    // Proves that a same-FU consumer waits on its producer's ROB tag,
    // wakes from the CDB, and then commits after the producer.
    task automatic test_same_fu_dependency;
        begin
            print_header("Same-FU RAW dependency");
            reset_dut(SCENARIO_SAME_FU);

            initialize_register(1'b0, REG_ADDR_W'(2), XLEN'(10));
            initialize_register(1'b0, REG_ADDR_W'(3), XLEN'(20));
            initialize_register(1'b0, REG_ADDR_W'(5), XLEN'(5));

            dispatch_instruction(
                1'b0,
                OP_ADD,
                REG_ADDR_W'(2),
                REG_ADDR_W'(3),
                REG_ADDR_W'(1)
            );
            dispatch_instruction(
                1'b0,
                OP_ADD,
                REG_ADDR_W'(1),
                REG_ADDR_W'(5),
                REG_ADDR_W'(4)
            );

            wait_for_commits(2);

            if (broadcast_count != 2) begin
                $fatal(1, "Expected exactly 2 broadcasts, observed %0d", broadcast_count);
            end

            check_cdb_event(0, 0, 30);
            check_cdb_event(1, 1, 35);
            check_commit_event(0, 0, 1, 30);
            check_commit_event(1, 1, 4, 35);
            check_backend_empty(1'b0);

            $display("[PASS] Same-FU RAW dependency");
        end
    endtask

    // Proves that a younger independent ADD may write back before an
    // older MUL while the ROB still commits instructions in order.
    task automatic test_ooo_completion;
        begin
            print_header("Out-of-order completion with in-order commit");
            reset_dut(SCENARIO_OOO);

            initialize_register(1'b0, REG_ADDR_W'(2), XLEN'(4));
            initialize_register(1'b0, REG_ADDR_W'(3), XLEN'(5));
            initialize_register(1'b0, REG_ADDR_W'(5), XLEN'(7));
            initialize_register(1'b0, REG_ADDR_W'(6), XLEN'(8));

            dispatch_instruction(
                1'b0,
                OP_MUL,
                REG_ADDR_W'(2),
                REG_ADDR_W'(3),
                REG_ADDR_W'(1)
            );
            dispatch_instruction(
                1'b0,
                OP_ADD,
                REG_ADDR_W'(5),
                REG_ADDR_W'(6),
                REG_ADDR_W'(4)
            );

            wait_for_commits(2);

            if (broadcast_count != 2) begin
                $fatal(1, "Expected exactly 2 broadcasts, observed %0d", broadcast_count);
            end

            check_cdb_event(0, 1, 15);
            check_cdb_event(1, 0, 20);
            check_commit_event(0, 0, 1, 20);
            check_commit_event(1, 1, 4, 15);
            check_backend_empty(1'b0);

            $display("[PASS] Out-of-order completion with in-order commit");
        end
    endtask

    // Proves that a MUL result wakes a dependent ADD in another
    // functional-unit reservation station before in-order commit.
    task automatic test_cross_fu_dependency;
        begin
            print_header("Cross-FU dependency");
            reset_dut(SCENARIO_CROSS_FU);

            initialize_register(1'b0, REG_ADDR_W'(2), XLEN'(4));
            initialize_register(1'b0, REG_ADDR_W'(3), XLEN'(5));
            initialize_register(1'b0, REG_ADDR_W'(5), XLEN'(7));

            dispatch_instruction(
                1'b0,
                OP_MUL,
                REG_ADDR_W'(2),
                REG_ADDR_W'(3),
                REG_ADDR_W'(1)
            );
            dispatch_instruction(
                1'b0,
                OP_ADD,
                REG_ADDR_W'(1),
                REG_ADDR_W'(5),
                REG_ADDR_W'(4)
            );

            wait_for_commits(2);

            if (broadcast_count != 2) begin
                $fatal(1, "Expected exactly 2 broadcasts, observed %0d", broadcast_count);
            end

            check_cdb_event(0, 0, 20);
            check_cdb_event(1, 1, 27);
            check_commit_event(0, 0, 1, 20);
            check_commit_event(1, 1, 4, 27);
            check_backend_empty(1'b0);

            $display("[PASS] Cross-FU dependency");
        end
    endtask

    // Uses the latency-3 DUT to align ALU and MUL completion. Proves
    // fixed-priority ALU arbitration, one-cycle MUL retention, and
    // in-order commit despite the younger ADD broadcasting first.
    task automatic test_cdb_collision;
        begin
            print_header("CDB collision and backpressure");
            reset_dut(SCENARIO_COLLISION);

            initialize_register(1'b1, REG_ADDR_W'(2), XLEN'(4));
            initialize_register(1'b1, REG_ADDR_W'(3), XLEN'(5));
            initialize_register(1'b1, REG_ADDR_W'(5), XLEN'(7));
            initialize_register(1'b1, REG_ADDR_W'(6), XLEN'(8));

            dispatch_instruction(
                1'b1,
                OP_MUL,
                REG_ADDR_W'(2),
                REG_ADDR_W'(3),
                REG_ADDR_W'(1)
            );
            dispatch_instruction(
                1'b1,
                OP_ADD,
                REG_ADDR_W'(5),
                REG_ADDR_W'(6),
                REG_ADDR_W'(4)
            );

            wait_for_commits(2);

            if (!saw_collision) begin
                $fatal(1, "Expected simultaneous ALU and MUL result-valid collision");
            end

            if (waiting_for_held_mul) begin
                $fatal(1, "MUL result remained pending after collision");
            end

            if (broadcast_count != 2) begin
                $fatal(1, "Expected exactly 2 broadcasts, observed %0d", broadcast_count);
            end

            check_cdb_event(0, 1, 15);
            check_cdb_event(1, 0, 20);
            check_commit_event(0, 0, 1, 20);
            check_commit_event(1, 1, 4, 15);
            check_backend_empty(1'b1);

            $display("[PASS] CDB collision and backpressure");
        end
    endtask

    // I0 writes R1 through ROB0, I1 is the newer R1 writer through
    // ROB1, and I2 reads R1. Proves that I2 depends on ROB1 rather
    // than the older ROB0 producer, even when ROB1 writes back first.
    task automatic test_waw_newest_producer;
        begin
            print_header("WAW newest-producer behavior");
            reset_dut(SCENARIO_WAW);

            initialize_register(1'b0, REG_ADDR_W'(2), XLEN'(4));
            initialize_register(1'b0, REG_ADDR_W'(3), XLEN'(5));
            initialize_register(1'b0, REG_ADDR_W'(4), XLEN'(7));
            initialize_register(1'b0, REG_ADDR_W'(5), XLEN'(8));
            initialize_register(1'b0, REG_ADDR_W'(7), XLEN'(3));

            dispatch_instruction(
                1'b0,
                OP_MUL,
                REG_ADDR_W'(2),
                REG_ADDR_W'(3),
                REG_ADDR_W'(1)
            );
            dispatch_instruction(
                1'b0,
                OP_ADD,
                REG_ADDR_W'(4),
                REG_ADDR_W'(5),
                REG_ADDR_W'(1)
            );
            dispatch_instruction(
                1'b0,
                OP_ADD,
                REG_ADDR_W'(1),
                REG_ADDR_W'(7),
                REG_ADDR_W'(6)
            );

            wait_for_commits(3);

            if (broadcast_count != 3) begin
                $fatal(1, "Expected exactly 3 broadcasts, observed %0d", broadcast_count);
            end

            if (!saw_rob1_waw_broadcast) begin
                $fatal(1, "ROB1 result 15 was not observed");
            end

            check_cdb_event(0, 1, 15);
            check_cdb_event(1, 0, 20);
            check_cdb_event(2, 2, 18);

            check_commit_event(0, 0, 1, 20);
            check_commit_event(1, 1, 1, 15);
            check_commit_event(2, 2, 6, 18);
            check_backend_empty(1'b0);

            $display("[PASS] WAW newest-producer behavior");
        end
    endtask

    // Proves that a new rename allocation wins over commit cleanup when
    // both update the same architectural register on one clock edge.
    //
    // I0 commits R1 = 30 while I1 simultaneously renames R1 to ROB1.
    // I2 must therefore wait for ROB1 = 20 and produce 23, not use the
    // newly committed value 30 and incorrectly produce 33.
    task automatic test_same_cycle_commit_and_rename;
        begin
            print_header("Same-cycle commit and rename");

            reset_dut(SCENARIO_COMMIT_RENAME);

            initialize_register(1'b0, REG_ADDR_W'(2), XLEN'(10));
            initialize_register(1'b0, REG_ADDR_W'(3), XLEN'(20));
            initialize_register(1'b0, REG_ADDR_W'(4), XLEN'(4));
            initialize_register(1'b0, REG_ADDR_W'(5), XLEN'(5));
            initialize_register(1'b0, REG_ADDR_W'(7), XLEN'(3));

            // I0: ADD R1, R2, R3
            // ROB0 produces 30.
            dispatch_instruction(
                1'b0,
                OP_ADD,
                REG_ADDR_W'(2),
                REG_ADDR_W'(3),
                REG_ADDR_W'(1)
            );

            // Wait until ROB0 writes back. ROB0 should become eligible to
            // commit on the following rising edge.
            wait_for_broadcasts(1);
            check_cdb_event(0, 0, 30);

            // I1: MUL R1, R4, R5
            //
            // Dispatch this on the same rising edge that ROB0 commits R1.
            // The new R1 -> ROB1 rename must take priority over clearing
            // the old ROB0 mapping.
            dispatch_on_commit(
                OP_MUL,
                REG_ADDR_W'(4),
                REG_ADDR_W'(5),
                REG_ADDR_W'(1),
                0,
                1,
                30
            );

            // I2: ADD R6, R1, R7
            //
            // It must depend on I1/ROB1 and calculate 20 + 3 = 23.
            dispatch_instruction(
                1'b0,
                OP_ADD,
                REG_ADDR_W'(1),
                REG_ADDR_W'(7),
                REG_ADDR_W'(6)
            );

            wait_for_commits(3);

            if (!saw_same_cycle_commit_rename) begin
                $fatal(
                    1,
                    "Did not observe simultaneous commit and rename"
                );
            end

            if (broadcast_count != 3) begin
                $fatal(
                    1,
                    "Expected exactly 3 broadcasts, observed %0d",
                    broadcast_count
                );
            end

            check_cdb_event(0, 0, 30);
            check_cdb_event(1, 1, 20);
            check_cdb_event(2, 2, 23);

            check_commit_event(0, 0, 1, 30);
            check_commit_event(1, 1, 1, 20);
            check_commit_event(2, 2, 6, 23);

            check_backend_empty(1'b0);

            $display("[PASS] Same-cycle commit and rename");
        end
    endtask

    // Fills all four ROB entries behind a long-latency head, proves a fifth
    // instruction cannot partially dispatch, then checks wrapped-tag reuse.
    task automatic test_rob_full_backpressure;
        begin
            print_header("ROB-full dispatch backpressure");
            reset_dut(SCENARIO_ROB_FULL);

            initialize_register(1'b0, REG_ADDR_W'(2), XLEN'(2));
            initialize_register(1'b0, REG_ADDR_W'(3), XLEN'(3));
            initialize_register(1'b0, REG_ADDR_W'(5), XLEN'(4));
            initialize_register(1'b0, REG_ADDR_W'(7), XLEN'(5));

            // ROB0: MUL R1, R2, R3 = 6
            // ROB1: ADD R4, R1, R5 = 10
            // ROB2: ADD R6, R1, R7 = 11
            // ROB3: MUL R2, R4, R5 = 40
            drive_main_instruction(OP_MUL, REG_ADDR_W'(2), REG_ADDR_W'(3), REG_ADDR_W'(1));
            drive_main_instruction(OP_ADD, REG_ADDR_W'(1), REG_ADDR_W'(5), REG_ADDR_W'(4));
            drive_main_instruction(OP_ADD, REG_ADDR_W'(1), REG_ADDR_W'(7), REG_ADDR_W'(6));
            drive_main_instruction(OP_MUL, REG_ADDR_W'(4), REG_ADDR_W'(5), REG_ADDR_W'(2));

            if (main_rob_count != ROB_COUNT_W'(NUM_ROB_ENTRIES)) begin
                $fatal(1, "Expected full ROB before fifth instruction, got %0d", main_rob_count);
            end

            hold_instruction_and_expect_blocked(
                OP_ADD,
                REG_ADDR_W'(3),
                REG_ADDR_W'(5),
                REG_ADDR_W'(7),
                4,
                2,
                1,
                "ROB full; dispatch blocked"
            );

            // Re-present the blocked instruction. It must wait for ROB0 to
            // commit, then allocate the newly free wrapped ROB0 slot.
            dispatch_instruction(
                1'b0,
                OP_ADD,
                REG_ADDR_W'(3),
                REG_ADDR_W'(5),
                REG_ADDR_W'(7)
            );
            $display("[CYCLE %0d] Dispatch resumed", cycle);

            wait_for_commits(5);

            if (broadcast_count != 5) begin
                $fatal(1, "Expected exactly 5 broadcasts, observed %0d", broadcast_count);
            end

            check_cdb_event(0, 0, 6);
            check_cdb_event(1, 1, 10);
            check_cdb_event(2, 0, 7);
            check_cdb_event(3, 2, 11);
            check_cdb_event(4, 3, 40);
            check_commit_event(0, 0, 1, 6);
            check_commit_event(1, 1, 4, 10);
            check_commit_event(2, 2, 6, 11);
            check_commit_event(3, 3, 2, 40);
            check_commit_event(4, 0, 7, 7);
            check_backend_empty(1'b0);

            $display("[PASS] ROB-full dispatch backpressure");
        end
    endtask

    // Proves each operation class is blocked only by its selected RS. Each
    // subtest blocks one operation, accepts the other, and drains completely.
    task automatic test_selected_rs_backpressure;
        begin
            print_header("Selected reservation-station backpressure");
            $display("[SUBTEST] ALU RS full");
            reset_dut(SCENARIO_RS_BACKPRESSURE);

            initialize_register(1'b0, REG_ADDR_W'(2), XLEN'(2));
            initialize_register(1'b0, REG_ADDR_W'(3), XLEN'(3));
            initialize_register(1'b0, REG_ADDR_W'(5), XLEN'(4));
            initialize_register(1'b0, REG_ADDR_W'(7), XLEN'(5));

            drive_main_instruction(OP_MUL, REG_ADDR_W'(2), REG_ADDR_W'(3), REG_ADDR_W'(1));
            drive_main_instruction(OP_ADD, REG_ADDR_W'(1), REG_ADDR_W'(5), REG_ADDR_W'(4));
            drive_main_instruction(OP_ADD, REG_ADDR_W'(1), REG_ADDR_W'(7), REG_ADDR_W'(6));

            hold_instruction_and_expect_blocked(
                OP_ADD,
                REG_ADDR_W'(2),
                REG_ADDR_W'(3),
                REG_ADDR_W'(7),
                3,
                2,
                0,
                "ADD blocked by full ALU RS"
            );

            drive_main_instruction(OP_MUL, REG_ADDR_W'(2), REG_ADDR_W'(2), REG_ADDR_W'(7));
            if (main_rob_count != ROB_COUNT_W'(4)) begin
                $fatal(1, "Nonselected MUL was not accepted with ALU RS full");
            end
            $display("[CYCLE %0d] ADD blocked; MUL accepted", cycle);
            @(negedge clk);
            clear_main_inputs();

            wait_for_commits(4);
            if (broadcast_count != 4) begin
                $fatal(1, "ALU-RS subtest expected 4 broadcasts, got %0d", broadcast_count);
            end
            check_cdb_event(0, 0, 6);
            check_cdb_event(1, 1, 10);
            check_cdb_event(2, 2, 11);
            check_cdb_event(3, 3, 4);
            check_commit_event(0, 0, 1, 6);
            check_commit_event(1, 1, 4, 10);
            check_commit_event(2, 2, 6, 11);
            check_commit_event(3, 3, 7, 4);
            check_backend_empty(1'b0);

            $display("\n[SUBTEST] MUL RS full");
            reset_dut(SCENARIO_RS_BACKPRESSURE);

            initialize_register(1'b0, REG_ADDR_W'(2), XLEN'(2));
            initialize_register(1'b0, REG_ADDR_W'(3), XLEN'(3));
            initialize_register(1'b0, REG_ADDR_W'(5), XLEN'(4));
            initialize_register(1'b0, REG_ADDR_W'(7), XLEN'(5));

            drive_main_instruction(OP_MUL, REG_ADDR_W'(2), REG_ADDR_W'(3), REG_ADDR_W'(1));
            drive_main_instruction(OP_MUL, REG_ADDR_W'(1), REG_ADDR_W'(5), REG_ADDR_W'(4));
            drive_main_instruction(OP_MUL, REG_ADDR_W'(1), REG_ADDR_W'(7), REG_ADDR_W'(6));

            hold_instruction_and_expect_blocked(
                OP_MUL,
                REG_ADDR_W'(2),
                REG_ADDR_W'(3),
                REG_ADDR_W'(7),
                3,
                0,
                2,
                "MUL blocked by full MUL RS"
            );

            drive_main_instruction(OP_ADD, REG_ADDR_W'(3), REG_ADDR_W'(5), REG_ADDR_W'(2));
            if (main_rob_count != ROB_COUNT_W'(4)) begin
                $fatal(1, "Nonselected ADD was not accepted with MUL RS full");
            end
            $display("[CYCLE %0d] MUL blocked; ADD accepted", cycle);
            @(negedge clk);
            clear_main_inputs();

            wait_for_commits(4);
            if (broadcast_count != 4) begin
                $fatal(1, "MUL-RS subtest expected 4 broadcasts, got %0d", broadcast_count);
            end
            check_cdb_event(0, 0, 6);
            check_cdb_event(1, 3, 7);
            check_cdb_event(2, 2, 30);
            check_cdb_event(3, 1, 24);
            check_commit_event(0, 0, 1, 6);
            check_commit_event(1, 1, 4, 24);
            check_commit_event(2, 2, 6, 30);
            check_commit_event(3, 3, 2, 7);
            check_backend_empty(1'b0);

            $display("[PASS] Selected reservation-station backpressure");
        end
    endtask

    // Runs six independent ADDs and checks circular tags, including two reused
    // slots with new destinations and values.
    task automatic test_rob_tag_wraparound;
        begin
            print_header("ROB tag wraparound");
            reset_dut(SCENARIO_ROB_WRAPAROUND);

            initialize_register(1'b0, REG_ADDR_W'(2), XLEN'(2));
            initialize_register(1'b0, REG_ADDR_W'(3), XLEN'(3));
            initialize_register(1'b0, REG_ADDR_W'(5), XLEN'(5));

            dispatch_instruction(1'b0, OP_ADD, REG_ADDR_W'(2), REG_ADDR_W'(3), REG_ADDR_W'(1));
            wait_for_broadcasts(1);
            dispatch_instruction(1'b0, OP_ADD, REG_ADDR_W'(2), REG_ADDR_W'(5), REG_ADDR_W'(4));
            wait_for_broadcasts(2);
            dispatch_instruction(1'b0, OP_ADD, REG_ADDR_W'(3), REG_ADDR_W'(5), REG_ADDR_W'(6));
            wait_for_broadcasts(3);
            dispatch_instruction(1'b0, OP_ADD, REG_ADDR_W'(2), REG_ADDR_W'(2), REG_ADDR_W'(7));
            wait_for_broadcasts(4);
            dispatch_instruction(1'b0, OP_ADD, REG_ADDR_W'(3), REG_ADDR_W'(3), REG_ADDR_W'(1));
            wait_for_broadcasts(5);
            dispatch_instruction(1'b0, OP_ADD, REG_ADDR_W'(5), REG_ADDR_W'(5), REG_ADDR_W'(4));

            wait_for_commits(6);

            if (broadcast_count != 6) begin
                $fatal(1, "Expected exactly 6 broadcasts, observed %0d", broadcast_count);
            end

            check_cdb_event(0, 0, 5);
            check_cdb_event(1, 1, 7);
            check_cdb_event(2, 2, 8);
            check_cdb_event(3, 3, 4);
            check_cdb_event(4, 0, 6);
            check_cdb_event(5, 1, 10);

            check_commit_event(0, 0, 1, 5);
            check_commit_event(1, 1, 4, 7);
            check_commit_event(2, 2, 6, 8);
            check_commit_event(3, 3, 7, 4);
            check_commit_event(4, 0, 1, 6);
            check_commit_event(5, 1, 4, 10);
            check_backend_empty(1'b0);

            $display("[PASS] ROB tag wraparound");
        end
    endtask

    // Resets a running MUL and dependent ADD, observes an empty idle window,
    // then proves clean ROB0 allocation and execution after reset.
    task automatic test_reset_with_instructions_in_flight;
        int unsigned idle_broadcasts;
        int unsigned idle_commits;

        begin
            print_header("Reset with instructions in flight");
            reset_dut(SCENARIO_RESET_IN_FLIGHT);

            initialize_register(1'b0, REG_ADDR_W'(2), XLEN'(4));
            initialize_register(1'b0, REG_ADDR_W'(3), XLEN'(5));
            initialize_register(1'b0, REG_ADDR_W'(5), XLEN'(7));

            drive_main_instruction(OP_MUL, REG_ADDR_W'(2), REG_ADDR_W'(3), REG_ADDR_W'(1));
            drive_main_instruction(OP_ADD, REG_ADDR_W'(1), REG_ADDR_W'(5), REG_ADDR_W'(4));

            @(negedge clk);
            clear_main_inputs();
            main_rst_n = 1'b0;
            clear_status();
            scenario_id = SCENARIO_RESET_IN_FLIGHT;
            $display("[CYCLE %0d] Reset asserted with work in flight", cycle);

            repeat (2) begin
                @(posedge clk);
                #1;
                if (
                    main_rob_count != '0 ||
                    main_alu_rs_count != '0 ||
                    main_mul_rs_count != '0 ||
                    main_cdb_valid !== 1'b0 ||
                    main_commit_valid !== 1'b0
                ) begin
                    $fatal(1, "Reset did not clear backend state and outputs");
                end
            end

            @(negedge clk);
            main_rst_n = 1'b1;
            idle_broadcasts = broadcast_count;
            idle_commits    = commit_count;

            repeat (6) begin
                @(posedge clk);
                #1;
                if (
                    main_rob_count != '0 ||
                    main_alu_rs_count != '0 ||
                    main_mul_rs_count != '0 ||
                    main_cdb_valid !== 1'b0 ||
                    main_commit_valid !== 1'b0 ||
                    broadcast_count != idle_broadcasts ||
                    commit_count != idle_commits
                ) begin
                    $fatal(1, "Observed stale pre-reset work after reset release");
                end
            end
            $display("[CYCLE %0d] Post-reset backend empty", cycle);

            initialize_register(1'b0, REG_ADDR_W'(2), XLEN'(11));
            initialize_register(1'b0, REG_ADDR_W'(3), XLEN'(12));
            dispatch_instruction(
                1'b0,
                OP_ADD,
                REG_ADDR_W'(2),
                REG_ADDR_W'(3),
                REG_ADDR_W'(6)
            );

            wait_for_commits(1);
            if (broadcast_count != 1) begin
                $fatal(1, "Expected one post-reset broadcast, got %0d", broadcast_count);
            end
            check_cdb_event(0, 0, 23);
            check_commit_event(0, 0, 6, 23);
            check_backend_empty(1'b0);

            $display("[PASS] Reset with instructions in flight");
        end
    endtask

    // ============================================================
    // Event monitors
    // ============================================================

    // Blocking assignments keep each captured event and its ordering checks
    // atomic within this testbench-only monitor.
    /* verilator lint_off BLKSEQ */
    always @(posedge clk) begin
        if (
            scenario_id != SCENARIO_NONE &&
            scenario_id != SCENARIO_COLLISION
        ) begin
            // Cycle tracking
            cycle = cycle + 1;
            #1;

            // CDB capture and scenario-specific ordering checks
            if (main_cdb_valid) begin
                $display(
                    "[CYCLE %0d] CDB ROB%0d = %0d",
                    cycle,
                    main_cdb_tag,
                    main_cdb_value
                );

                if (broadcast_count >= MAX_EVENTS) begin
                    $fatal(1, "CDB event capture overflow");
                end

                cdb_tags[broadcast_count]   = main_cdb_tag;
                cdb_values[broadcast_count] = main_cdb_value;
                broadcast_count            = broadcast_count + 1;

                if (
                    scenario_id == SCENARIO_CROSS_FU &&
                    main_cdb_tag == TAG_W'(1) &&
                    !(
                        broadcast_count >= 2 &&
                        cdb_tags[0] == TAG_W'(0) &&
                        cdb_values[0] == XLEN'(20)
                    )
                ) begin
                    $fatal(1, "Dependent ROB1 broadcast before ROB0 MUL");
                end

                if (scenario_id == SCENARIO_WAW) begin
                    if (
                        main_cdb_tag == TAG_W'(1) &&
                        main_cdb_value == XLEN'(15)
                    ) begin
                        saw_rob1_waw_broadcast = 1'b1;
                    end

                    if (main_cdb_tag == TAG_W'(2)) begin
                        if (main_cdb_value == XLEN'(23)) begin
                            $fatal(1, "ROB2 used stale ROB0 producer and produced 23");
                        end

                        if (main_cdb_value != XLEN'(18)) begin
                            $fatal(1, "ROB2 expected 18, got %0d", main_cdb_value);
                        end

                        if (!saw_rob1_waw_broadcast) begin
                            $fatal(1, "ROB2 completed before newer producer ROB1 broadcast");
                        end
                    end
                end

                if (
                    scenario_id == SCENARIO_COMMIT_RENAME &&
                    main_cdb_tag == TAG_W'(2)
                ) begin
                    if (main_cdb_value == XLEN'(33)) begin
                        $fatal(
                            1,
                            "ROB2 used committed R1=30 instead of newer ROB1 producer"
                        );
                    end

                    if (main_cdb_value != XLEN'(23)) begin
                        $fatal(
                            1,
                            "ROB2 expected 23, got %0d",
                            main_cdb_value
                        );
                    end
                end
            end

            // Commit capture
            if (main_commit_valid) begin
                $display(
                    "[CYCLE %0d] COMMIT ROB%0d: R%0d = %0d",
                    cycle,
                    main_commit_tag,
                    main_commit_dest_reg,
                    main_commit_value
                );

                if (commit_count >= MAX_EVENTS) begin
                    $fatal(1, "Commit event capture overflow");
                end

                commit_tags[commit_count]      = main_commit_tag;
                commit_dest_regs[commit_count] = main_commit_dest_reg;
                commit_values[commit_count]    = main_commit_value;
                commit_count                   = commit_count + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (scenario_id == SCENARIO_COLLISION) begin
            // Cycle tracking
            cycle = cycle + 1;
            #1;

            // CDB arbitration and held-result checks
            if (
                collision_alu_result_valid_debug &&
                collision_mul_result_valid_debug
            ) begin
                $display(
                    "[CYCLE %0d] CDB COLLISION: ALU and MUL both valid",
                    cycle
                );

                if (!collision_alu_result_ready_debug) begin
                    $fatal(1, "ALU should win fixed-priority arbitration");
                end

                if (collision_mul_result_ready_debug) begin
                    $fatal(1, "MUL should be backpressured during collision");
                end

                if (
                    !collision_cdb_valid ||
                    collision_cdb_tag != TAG_W'(1) ||
                    collision_cdb_value != XLEN'(15)
                ) begin
                    $fatal(1, "Collision CDB must carry ALU ROB1 = 15");
                end

                collision_cycle      = cycle;
                saw_collision        = 1'b1;
                waiting_for_held_mul = 1'b1;
            end

            if (collision_cdb_valid) begin
                $display(
                    "[CYCLE %0d] CDB ROB%0d = %0d",
                    cycle,
                    collision_cdb_tag,
                    collision_cdb_value
                );

                if (broadcast_count >= MAX_EVENTS) begin
                    $fatal(1, "CDB event capture overflow");
                end

                cdb_tags[broadcast_count]   = collision_cdb_tag;
                cdb_values[broadcast_count] = collision_cdb_value;
                broadcast_count            = broadcast_count + 1;

                if (
                    collision_cdb_tag == TAG_W'(0) &&
                    collision_cdb_value == XLEN'(20)
                ) begin
                    if (!waiting_for_held_mul) begin
                        $fatal(1, "MUL broadcast occurred without an observed collision");
                    end

                    if (cycle != collision_cycle + 1) begin
                        $fatal(
                            1,
                            "Held MUL result expected one cycle after collision: collision=%0d broadcast=%0d",
                            collision_cycle,
                            cycle
                        );
                    end

                    waiting_for_held_mul = 1'b0;
                end
            end

            // Commit capture
            if (collision_commit_valid) begin
                $display(
                    "[CYCLE %0d] COMMIT ROB%0d: R%0d = %0d",
                    cycle,
                    collision_commit_tag,
                    collision_commit_dest_reg,
                    collision_commit_value
                );

                if (commit_count >= MAX_EVENTS) begin
                    $fatal(1, "Commit event capture overflow");
                end

                commit_tags[commit_count]      = collision_commit_tag;
                commit_dest_regs[commit_count] = collision_commit_dest_reg;
                commit_values[commit_count]    = collision_commit_value;
                commit_count                   = commit_count + 1;
            end
        end
    end
    /* verilator lint_on BLKSEQ */

    // ============================================================
    // Main regression sequence
    // ============================================================

    initial begin
        $dumpfile("waves/backend_tb.vcd");
        $dumpvars(0, backend_tb);

        scenario_id     = SCENARIO_NONE;
        main_rst_n      = 1'b0;
        collision_rst_n = 1'b0;

        clear_main_inputs();
        clear_collision_inputs();
        clear_status();

        test_basic();
        test_same_fu_dependency();
        test_ooo_completion();
        test_cross_fu_dependency();
        test_cdb_collision();
        test_waw_newest_producer();
        test_same_cycle_commit_and_rename();
        test_rob_full_backpressure();
        test_selected_rs_backpressure();
        test_rob_tag_wraparound();
        test_reset_with_instructions_in_flight();

        scenario_id     = SCENARIO_NONE;
        main_rst_n      = 1'b0;
        collision_rst_n = 1'b0;

        $display("backend_tb PASSED: 11 scenarios");
        $finish;
    end

    // ============================================================
    // Global watchdog
    // ============================================================

    initial begin
        repeat (1200) @(posedge clk);
        $fatal(1, "backend_tb timed out");
    end

endmodule

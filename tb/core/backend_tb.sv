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
    localparam int MAX_EVENTS          = 8;
    localparam int MAX_WAIT_CYCLES     = 80;

    localparam logic [OP_W-1:0] OP_ADD = 4'd0;
    localparam logic [OP_W-1:0] OP_MUL = 4'd5;

    // ============================================================
    // Scenario identifiers
    // ============================================================

    localparam int SCENARIO_NONE       = 0;
    localparam int SCENARIO_BASIC      = 1;
    localparam int SCENARIO_SAME_FU    = 2;
    localparam int SCENARIO_OOO        = 3;
    localparam int SCENARIO_CROSS_FU   = 4;
    localparam int SCENARIO_COLLISION  = 5;
    localparam int SCENARIO_WAW        = 6;

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

        scenario_id     = SCENARIO_NONE;
        main_rst_n      = 1'b0;
        collision_rst_n = 1'b0;

        $display("backend_tb PASSED: 6 scenarios");
        $finish;
    end

    // ============================================================
    // Global watchdog
    // ============================================================

    initial begin
        repeat (600) @(posedge clk);
        $fatal(1, "backend_tb timed out");
    end

endmodule

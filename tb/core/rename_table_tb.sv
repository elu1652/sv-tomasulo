`timescale 1ns/1ps

module rename_table_tb;

    localparam int NUM_REGS   = 8;
    localparam int REG_ADDR_W = 3;
    localparam int TAG_W      = 3;

    logic clk;
    logic rst_n;

    logic [REG_ADDR_W-1:0] src1_reg;
    logic                  src1_pending;
    logic [TAG_W-1:0]      src1_tag;

    logic [REG_ADDR_W-1:0] src2_reg;
    logic                  src2_pending;
    logic [TAG_W-1:0]      src2_tag;

    logic                  rename_valid;
    logic [REG_ADDR_W-1:0] rename_dest_reg;
    logic [TAG_W-1:0]      rename_dest_tag;

    logic                  commit_valid;
    logic [REG_ADDR_W-1:0] commit_dest_reg;
    logic [TAG_W-1:0]      commit_tag;

    rename_table #(
        .NUM_REGS(NUM_REGS),
        .REG_ADDR_W(REG_ADDR_W),
        .TAG_W(TAG_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .src1_reg(src1_reg),
        .src1_pending(src1_pending),
        .src1_tag(src1_tag),

        .src2_reg(src2_reg),
        .src2_pending(src2_pending),
        .src2_tag(src2_tag),

        .rename_valid(rename_valid),
        .rename_dest_reg(rename_dest_reg),
        .rename_dest_tag(rename_dest_tag),

        .commit_valid(commit_valid),
        .commit_dest_reg(commit_dest_reg),
        .commit_tag(commit_tag)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic reset_dut;
        begin
            rst_n = 1'b0;

            src1_reg = '0;
            src2_reg = '0;

            rename_valid    = 1'b0;
            rename_dest_reg = '0;
            rename_dest_tag = '0;

            commit_valid    = 1'b0;
            commit_dest_reg = '0;
            commit_tag      = '0;

            repeat (2) @(posedge clk);

            @(negedge clk);
            rst_n = 1'b1;

            @(posedge clk);
            #1;

            $display("SUCCESS: reset");
        end
    endtask

    task automatic lookup_src1(
        input logic [REG_ADDR_W-1:0] reg_id,
        input logic                  expected_pending,
        input logic [TAG_W-1:0]      expected_tag
    );
        begin
            src1_reg = reg_id;
            #1;

            if (src1_pending !== expected_pending) begin
                $display(
                    "ERROR: src1 R%0d expected pending=%0b, got %0b",
                    reg_id,
                    expected_pending,
                    src1_pending
                );
                $fatal;
            end

            if (src1_tag !== expected_tag) begin
                $display(
                    "ERROR: src1 R%0d expected tag ROB%0d, got ROB%0d",
                    reg_id,
                    expected_tag,
                    src1_tag
                );
                $fatal;
            end

            $display(
                "SUCCESS: src1 R%0d pending=%0b tag=ROB%0d",
                reg_id,
                src1_pending,
                src1_tag
            );
        end
    endtask

    task automatic lookup_src2(
        input logic [REG_ADDR_W-1:0] reg_id,
        input logic                  expected_pending,
        input logic [TAG_W-1:0]      expected_tag
    );
        begin
            src2_reg = reg_id;
            #1;

            if (src2_pending !== expected_pending) begin
                $display(
                    "ERROR: src2 R%0d expected pending=%0b, got %0b",
                    reg_id,
                    expected_pending,
                    src2_pending
                );
                $fatal;
            end

            if (src2_tag !== expected_tag) begin
                $display(
                    "ERROR: src2 R%0d expected tag ROB%0d, got ROB%0d",
                    reg_id,
                    expected_tag,
                    src2_tag
                );
                $fatal;
            end

            $display(
                "SUCCESS: src2 R%0d pending=%0b tag=ROB%0d",
                reg_id,
                src2_pending,
                src2_tag
            );
        end
    endtask

    task automatic rename_dest(
        input logic [REG_ADDR_W-1:0] dest_reg,
        input logic [TAG_W-1:0]      dest_tag
    );
        begin
            @(negedge clk);

            rename_valid    = 1'b1;
            rename_dest_reg = dest_reg;
            rename_dest_tag = dest_tag;

            @(posedge clk);
            #1;

            rename_valid    = 1'b0;
            rename_dest_reg = '0;
            rename_dest_tag = '0;

            $display("SUCCESS: renamed R%0d -> ROB%0d", dest_reg, dest_tag);
        end
    endtask

    task automatic commit_dest(
        input logic [REG_ADDR_W-1:0] dest_reg,
        input logic [TAG_W-1:0]      rob_tag
    );
        begin
            @(negedge clk);

            commit_valid    = 1'b1;
            commit_dest_reg = dest_reg;
            commit_tag      = rob_tag;

            @(posedge clk);
            #1;

            commit_valid    = 1'b0;
            commit_dest_reg = '0;
            commit_tag      = '0;

            $display("SUCCESS: committed ROB%0d for R%0d", rob_tag, dest_reg);
        end
    endtask

    task automatic same_cycle_commit_and_rename(
        input logic [REG_ADDR_W-1:0] commit_reg,
        input logic [TAG_W-1:0]      old_tag,
        input logic [REG_ADDR_W-1:0] rename_reg,
        input logic [TAG_W-1:0]      new_tag
    );
        begin
            @(negedge clk);

            commit_valid    = 1'b1;
            commit_dest_reg = commit_reg;
            commit_tag      = old_tag;

            rename_valid    = 1'b1;
            rename_dest_reg = rename_reg;
            rename_dest_tag = new_tag;

            @(posedge clk);
            #1;

            commit_valid    = 1'b0;
            commit_dest_reg = '0;
            commit_tag      = '0;

            rename_valid    = 1'b0;
            rename_dest_reg = '0;
            rename_dest_tag = '0;

            $display(
                "SUCCESS: same-cycle commit ROB%0d and rename R%0d -> ROB%0d",
                old_tag,
                rename_reg,
                new_tag
            );
        end
    endtask

    initial begin
        $dumpfile("rename_table_tb.vcd");
        $dumpvars(0, rename_table_tb);

        $display("Number of registers: %0d", NUM_REGS);

        reset_dut();

        // After reset, no register should be pending.
        lookup_src1(3'd1, 1'b0, 3'd0);
        lookup_src2(3'd2, 1'b0, 3'd0);

        // Basic rename:
        // R1 is now waiting for ROB0.
        rename_dest(3'd1, 3'd0);
        lookup_src1(3'd1, 1'b1, 3'd0);

        // A different register should still not be pending.
        lookup_src2(3'd2, 1'b0, 3'd0);

        // Commit ROB0 for R1.
        // Since R1 still points to ROB0, the mapping should clear.
        commit_dest(3'd1, 3'd0);
        lookup_src1(3'd1, 1'b0, 3'd0);

        // WAW case:
        // I0 writes R1 -> ROB0
        // I1 writes R1 -> ROB1
        rename_dest(3'd1, 3'd0);
        rename_dest(3'd1, 3'd1);
        lookup_src1(3'd1, 1'b1, 3'd1);

        // Commit older ROB0.
        // This must NOT clear R1 because R1 now points to newer ROB1.
        commit_dest(3'd1, 3'd0);
        lookup_src1(3'd1, 1'b1, 3'd1);

        // Commit newer ROB1.
        // Now the mapping should clear.
        commit_dest(3'd1, 3'd1);
        lookup_src1(3'd1, 1'b0, 3'd0);

        // R0 should ignore rename updates.
        rename_dest(3'd0, 3'd5);
        lookup_src1(3'd0, 1'b0, 3'd0);

        // Same-cycle commit and rename to the same architectural register.
        // New rename should win.
        rename_dest(3'd2, 3'd2);
        same_cycle_commit_and_rename(3'd2, 3'd2, 3'd2, 3'd3);
        lookup_src1(3'd2, 1'b1, 3'd3);

        commit_dest(3'd2, 3'd3);
        lookup_src1(3'd2, 1'b0, 3'd0);

        $display("RENAME TABLE TEST PASSED");
        $finish;
    end

endmodule

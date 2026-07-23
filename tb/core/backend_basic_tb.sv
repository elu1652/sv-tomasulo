`timescale 1ns/1ps

module backend_basic_tb;

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
    localparam logic [OP_W-1:0] OP_ADD = 4'd0;

    logic clk, rst_n;
    logic dispatch_valid, dispatch_ready;
    logic [OP_W-1:0] dispatch_op;
    logic [REG_ADDR_W-1:0] dispatch_src1_reg, dispatch_src2_reg;
    logic [REG_ADDR_W-1:0] dispatch_dest_reg;
    logic init_we;
    logic [REG_ADDR_W-1:0] init_waddr;
    logic [XLEN-1:0] init_wdata;
    logic commit_valid;
    logic [REG_ADDR_W-1:0] commit_dest_reg;
    logic [XLEN-1:0] commit_value;
    logic [TAG_W-1:0] commit_tag;
    logic [ROB_COUNT_W-1:0] rob_count;
    logic [ALU_RS_COUNT_W-1:0] alu_rs_count;
    logic [MUL_RS_COUNT_W-1:0] mul_rs_count;
    logic cdb_valid;
    logic [TAG_W-1:0] cdb_tag;
    logic [XLEN-1:0] cdb_value;
    logic alu_result_valid_debug, mul_result_valid_debug;
    logic alu_result_ready_debug, mul_result_ready_debug;
    int unsigned cycle, commit_count;
    logic saw_broadcast;

    backend #(
        .NUM_ROB_ENTRIES(NUM_ROB_ENTRIES),
        .NUM_ALU_RS_ENTRIES(NUM_ALU_RS_ENTRIES),
        .NUM_MUL_RS_ENTRIES(NUM_MUL_RS_ENTRIES),
        .NUM_REGS(NUM_REGS),
        .XLEN(XLEN),
        .OP_W(OP_W)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .dispatch_valid(dispatch_valid), .dispatch_ready(dispatch_ready),
        .dispatch_op(dispatch_op),
        .dispatch_src1_reg(dispatch_src1_reg),
        .dispatch_src2_reg(dispatch_src2_reg),
        .dispatch_dest_reg(dispatch_dest_reg),
        .init_we(init_we), .init_waddr(init_waddr), .init_wdata(init_wdata),
        .commit_valid(commit_valid), .commit_dest_reg(commit_dest_reg),
        .commit_value(commit_value), .commit_tag(commit_tag),
        .rob_count(rob_count), .alu_rs_count(alu_rs_count),
        .mul_rs_count(mul_rs_count),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .alu_result_valid_debug(alu_result_valid_debug),
        .mul_result_valid_debug(mul_result_valid_debug),
        .alu_result_ready_debug(alu_result_ready_debug),
        .mul_result_ready_debug(mul_result_ready_debug)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (!rst_n) cycle = 0;
        else cycle = cycle + 1;
        #1;
        if (cdb_valid) begin
            $display(
                "[CYCLE %0d] CDB ROB%0d = %0d",
                cycle,
                cdb_tag,
                cdb_value
            );

            if (cdb_tag != TAG_W'(0) || cdb_value != XLEN'(30))
                $fatal(1, "Unexpected CDB value: ROB%0d = %0d", cdb_tag, cdb_value);
            if (saw_broadcast)
                $fatal(1, "ROB0 broadcast more than once");
            saw_broadcast = 1'b1;
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
            if (commit_count != 1 ||
                commit_tag != TAG_W'(0) ||
                commit_dest_reg != REG_ADDR_W'(1) ||
                commit_value != XLEN'(30))
                $fatal(1, "Expected only commit to be ROB0: R1 = 30");
        end
    end

    task automatic initialize_register(
        input logic [REG_ADDR_W-1:0] reg_index,
        input logic [XLEN-1:0] value
    );
        @(negedge clk);
        init_we = 1'b1; init_waddr = reg_index; init_wdata = value;
        @(negedge clk);
        init_we = 1'b0; init_waddr = '0; init_wdata = '0;
    endtask

    task automatic dispatch_instruction(
        input logic [OP_W-1:0] op,
        input logic [REG_ADDR_W-1:0] src1_reg,
        input logic [REG_ADDR_W-1:0] src2_reg,
        input logic [REG_ADDR_W-1:0] dest_reg
    );
        int unsigned wait_cycles;
        @(negedge clk);
        dispatch_valid = 1'b1; dispatch_op = op;
        dispatch_src1_reg = src1_reg; dispatch_src2_reg = src2_reg;
        dispatch_dest_reg = dest_reg;
        wait_cycles = 0;
        while (!dispatch_ready && wait_cycles < 10) begin
            @(negedge clk);
            wait_cycles = wait_cycles + 1;
        end
        if (!dispatch_ready) $fatal(1, "Timed out waiting for dispatch_ready");
        @(negedge clk);
        dispatch_valid = 1'b0; dispatch_op = '0;
        dispatch_src1_reg = '0; dispatch_src2_reg = '0;
        dispatch_dest_reg = '0;
    endtask

    initial begin
        $dumpfile("waves/backend_basic_tb.vcd");
        $dumpvars(0, backend_basic_tb);
        rst_n = 1'b0;
        dispatch_valid = 1'b0; dispatch_op = '0;
        dispatch_src1_reg = '0; dispatch_src2_reg = '0;
        dispatch_dest_reg = '0;
        init_we = 1'b0; init_waddr = '0; init_wdata = '0;
        cycle = 0; commit_count = 0; saw_broadcast = 1'b0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        initialize_register(REG_ADDR_W'(2), XLEN'(10));
        initialize_register(REG_ADDR_W'(3), XLEN'(20));
        dispatch_instruction(OP_ADD, REG_ADDR_W'(2), REG_ADDR_W'(3), REG_ADDR_W'(1));
        repeat (20) @(posedge clk);
        @(negedge clk);
        if (!saw_broadcast) $fatal(1, "ROB0 never broadcast 30");
        if (commit_count != 1) $fatal(1, "Expected exactly 1 commit, observed %0d", commit_count);
        if (rob_count != '0 || alu_rs_count != '0 || mul_rs_count != '0)
            $fatal(1, "Backend not empty: ROB=%0d ALU_RS=%0d MUL_RS=%0d",
                   rob_count, alu_rs_count, mul_rs_count);
        $display("backend_basic_tb PASSED");
        $finish;
    end

    initial begin
        repeat (60) @(posedge clk);
        $fatal(1, "backend_basic_tb timed out");
    end

endmodule

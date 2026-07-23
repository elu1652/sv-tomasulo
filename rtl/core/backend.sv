`timescale 1ns/1ps

module backend #(
    parameter int NUM_ROB_ENTRIES    = 4,
    parameter int NUM_ALU_RS_ENTRIES = 2,
    parameter int NUM_MUL_RS_ENTRIES = 2,
    parameter int NUM_REGS           = 8,

    parameter int XLEN        = 32,
    parameter int OP_W        = 4,
    parameter int ALU_LATENCY = 1,
    parameter int MUL_LATENCY = 5,

    localparam int REG_ADDR_W =
        (NUM_REGS <= 1) ? 1 : $clog2(NUM_REGS),

    localparam int TAG_W =
        (NUM_ROB_ENTRIES <= 1) ? 1 : $clog2(NUM_ROB_ENTRIES),

    localparam int ROB_COUNT_W =
        $clog2(NUM_ROB_ENTRIES + 1),

    localparam int ALU_RS_COUNT_W =
        $clog2(NUM_ALU_RS_ENTRIES + 1),

    localparam int MUL_RS_COUNT_W =
        $clog2(NUM_MUL_RS_ENTRIES + 1)
) (
    input logic clk,
    input logic rst_n,

    // ------------------------------------------------------------
    // Decoded instruction input
    // ------------------------------------------------------------

    input  logic                  dispatch_valid,
    output logic                  dispatch_ready,

    input  logic [OP_W-1:0]       dispatch_op,
    input  logic [REG_ADDR_W-1:0] dispatch_src1_reg,
    input  logic [REG_ADDR_W-1:0] dispatch_src2_reg,
    input  logic [REG_ADDR_W-1:0] dispatch_dest_reg,

    // ------------------------------------------------------------
    // Testbench register-file initialization
    // ------------------------------------------------------------

    input logic                  init_we,
    input logic [REG_ADDR_W-1:0] init_waddr,
    input logic [XLEN-1:0]       init_wdata,

    // ------------------------------------------------------------
    // Commit observation
    // ------------------------------------------------------------

    output logic                  commit_valid,
    output logic [REG_ADDR_W-1:0] commit_dest_reg,
    output logic [XLEN-1:0]       commit_value,
    output logic [TAG_W-1:0]      commit_tag,

    // ------------------------------------------------------------
    // Debug/status outputs
    // ------------------------------------------------------------

    output logic [ROB_COUNT_W-1:0]    rob_count,
    output logic [ALU_RS_COUNT_W-1:0] alu_rs_count,
    output logic [MUL_RS_COUNT_W-1:0] mul_rs_count,

    output logic                 cdb_valid,
    output logic [TAG_W-1:0]     cdb_tag,
    output logic [XLEN-1:0]      cdb_value,

    output logic alu_result_valid_debug,
    output logic mul_result_valid_debug,
    output logic alu_result_ready_debug,
    output logic mul_result_ready_debug
);
    assign alu_result_valid_debug = alu_result_valid;
    assign mul_result_valid_debug = mul_result_valid;

    assign alu_result_ready_debug = alu_result_ready;
    assign mul_result_ready_debug = mul_result_ready;

    // ============================================================
    // Register file signals
    // ============================================================

    logic [REG_ADDR_W-1:0] rf_raddr1;
    logic [REG_ADDR_W-1:0] rf_raddr2;

    logic [XLEN-1:0] rf_rdata1;
    logic [XLEN-1:0] rf_rdata2;

    logic                  rf_we;
    logic [REG_ADDR_W-1:0] rf_waddr;
    logic [XLEN-1:0]       rf_wdata;

    // ============================================================
    // Rename-table signals
    // ============================================================

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

    // ============================================================
    // ROB signals
    // ============================================================

    logic                  rob_alloc_valid;
    logic                  rob_alloc_ready;
    logic [REG_ADDR_W-1:0] rob_alloc_dest_reg;
    logic [TAG_W-1:0]      rob_alloc_tag;

    logic              rob_wb_valid;
    logic [TAG_W-1:0]  rob_wb_tag;
    logic [XLEN-1:0]   rob_wb_value;

    logic                  rob_commit_valid;
    logic                  rob_commit_ready;
    logic [REG_ADDR_W-1:0] rob_commit_dest_reg;
    logic [XLEN-1:0]       rob_commit_value;
    logic [TAG_W-1:0]      rob_commit_tag;

    logic rob_commit_fire;

    // ============================================================
    // ALU reservation-station dispatch signals
    // ============================================================

    logic            alu_rs_dispatch_valid;
    logic            alu_rs_dispatch_ready;
    logic [OP_W-1:0] alu_rs_dispatch_op;

    logic              alu_rs_dispatch_src1_ready;
    logic [XLEN-1:0]   alu_rs_dispatch_src1_value;
    logic [TAG_W-1:0]  alu_rs_dispatch_src1_tag;

    logic              alu_rs_dispatch_src2_ready;
    logic [XLEN-1:0]   alu_rs_dispatch_src2_value;
    logic [TAG_W-1:0]  alu_rs_dispatch_src2_tag;

    logic [TAG_W-1:0] alu_rs_dispatch_dest_tag;

    // ============================================================
    // ALU reservation-station issue signals
    // ============================================================

    logic            alu_rs_issue_valid;
    logic            alu_rs_issue_ready;
    logic [OP_W-1:0] alu_rs_issue_op;

    logic [XLEN-1:0] alu_rs_issue_src1_value;
    logic [XLEN-1:0] alu_rs_issue_src2_value;
    logic [TAG_W-1:0] alu_rs_issue_dest_tag;

    // ============================================================
    // MUL reservation-station dispatch signals
    // ============================================================

    logic            mul_rs_dispatch_valid;
    logic            mul_rs_dispatch_ready;
    logic [OP_W-1:0] mul_rs_dispatch_op;

    logic             mul_rs_dispatch_src1_ready;
    logic [XLEN-1:0]  mul_rs_dispatch_src1_value;
    logic [TAG_W-1:0] mul_rs_dispatch_src1_tag;

    logic             mul_rs_dispatch_src2_ready;
    logic [XLEN-1:0]  mul_rs_dispatch_src2_value;
    logic [TAG_W-1:0] mul_rs_dispatch_src2_tag;

    logic [TAG_W-1:0] mul_rs_dispatch_dest_tag;

    // ============================================================
    // MUL reservation-station issue signals
    // ============================================================

    logic            mul_rs_issue_valid;
    logic            mul_rs_issue_ready;
    logic [OP_W-1:0] mul_rs_issue_op;

    logic [XLEN-1:0]  mul_rs_issue_src1_value;
    logic [XLEN-1:0]  mul_rs_issue_src2_value;
    logic [TAG_W-1:0] mul_rs_issue_dest_tag;

    // ============================================================
    // ALU functional-unit signals
    // ============================================================

    logic alu_fu_start;
    logic alu_fu_busy;

    logic             alu_result_valid;
    logic             alu_result_ready;
    logic [XLEN-1:0]  alu_result;
    logic [TAG_W-1:0] alu_result_tag;

    // ============================================================
    // MUL functional-unit signals
    // ============================================================

    logic mul_fu_start;
    logic mul_fu_busy;

    logic             mul_result_valid;
    logic             mul_result_ready;
    logic [XLEN-1:0]  mul_result;
    logic [TAG_W-1:0] mul_result_tag;

    // ============================================================
    // Dispatch
    // ============================================================

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

    // ============================================================
    // Register-file write-port selection
    // ============================================================

    always_comb begin
        if (init_we) begin
            rf_we    = 1'b1;
            rf_waddr = init_waddr;
            rf_wdata = init_wdata;
        end else begin
            rf_we    = rob_commit_valid;
            rf_waddr = rob_commit_dest_reg;
            rf_wdata = rob_commit_value;
        end
    end

    // ============================================================
    // Register file
    // ============================================================

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

    // ============================================================
    // Rename table
    // ============================================================

    rename_table #(
        .NUM_REGS(NUM_REGS),
        .REG_ADDR_W(REG_ADDR_W),
        .TAG_W(TAG_W)
    ) rename_dut (
        .clk(clk),
        .rst_n(rst_n),

        // Source lookups from dispatch
        .src1_reg(rename_src1_reg),
        .src1_pending(rename_src1_pending),
        .src1_tag(rename_src1_tag),

        .src2_reg(rename_src2_reg),
        .src2_pending(rename_src2_pending),
        .src2_tag(rename_src2_tag),

        // New destination mapping from dispatch
        .rename_valid(rename_valid),
        .rename_dest_reg(rename_dest_reg),
        .rename_dest_tag(rename_dest_tag),

        // Mapping cleanup from commit
        .commit_valid(rename_commit_valid),
        .commit_dest_reg(rename_commit_dest_reg),
        .commit_tag(rename_commit_tag)
    );

    assign rename_commit_valid    = rob_commit_fire;
    assign rename_commit_dest_reg = rob_commit_dest_reg;
    assign rename_commit_tag      = rob_commit_tag;

    // ============================================================
    // Reorder buffer
    // ============================================================

    rob #(
        .NUM_ENTRIES(NUM_ROB_ENTRIES),
        .REG_ADDR_W(REG_ADDR_W),
        .XLEN(XLEN)
    ) rob_dut (
        .clk(clk),
        .rst_n(rst_n),

        // Allocation from dispatch
        .alloc_valid(rob_alloc_valid),
        .alloc_ready(rob_alloc_ready),
        .alloc_dest_reg(rob_alloc_dest_reg),
        .alloc_tag(rob_alloc_tag),

        // Writeback from the CDB
        .wb_valid(rob_wb_valid),
        .wb_tag(rob_wb_tag),
        .wb_value(rob_wb_value),

        // In-order commit
        .commit_valid(rob_commit_valid),
        .commit_ready(rob_commit_ready),
        .commit_dest_reg(rob_commit_dest_reg),
        .commit_value(rob_commit_value),
        .commit_tag(rob_commit_tag),

        .count(rob_count)
    );

    // The backend always accepts a ready ROB-head entry.
    assign rob_commit_ready = 1'b1;

    // A commit happens when the ROB presents a valid ready head
    // and the backend accepts it.
    assign rob_commit_fire =
        rob_commit_valid && rob_commit_ready;

    // CDB writes completed results into the ROB.
    assign rob_wb_valid = cdb_valid;
    assign rob_wb_tag   = cdb_tag;
    assign rob_wb_value = cdb_value;

    // Public commit outputs for the testbench.
    assign commit_valid    = rob_commit_fire;
    assign commit_dest_reg = rob_commit_dest_reg;
    assign commit_value    = rob_commit_value;
    assign commit_tag      = rob_commit_tag;

    // ============================================================
    // ALU reservation station
    // ============================================================

    reservation_station #(
        .NUM_ENTRIES(NUM_ALU_RS_ENTRIES),
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

    // ============================================================
    // MUL reservation station
    // ============================================================

    reservation_station #(
        .NUM_ENTRIES(NUM_MUL_RS_ENTRIES),
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

    // ============================================================
    // Reservation-station to functional-unit handshakes
    // ============================================================

    assign alu_rs_issue_ready = !alu_fu_busy;
    assign mul_rs_issue_ready = !mul_fu_busy;

    assign alu_fu_start =
        alu_rs_issue_valid && alu_rs_issue_ready;

    assign mul_fu_start =
        mul_rs_issue_valid && mul_rs_issue_ready;

    // ============================================================
    // ALU functional unit
    // ============================================================

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

    // ============================================================
    // Multiply functional unit
    // ============================================================

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

    // ============================================================
    // Common data bus arbiter
    // ============================================================

    cdb_arbiter #(
        .XLEN(XLEN),
        .TAG_W(TAG_W)
    ) cdb_arbiter_dut (
        // Source 0: ALU
        .src0_valid(alu_result_valid),
        .src0_tag(alu_result_tag),
        .src0_value(alu_result),
        .src0_ready(alu_result_ready),

        // Source 1: MUL
        .src1_valid(mul_result_valid),
        .src1_tag(mul_result_tag),
        .src1_value(mul_result),
        .src1_ready(mul_result_ready),

        // Selected CDB broadcast
        .cdb_valid(cdb_valid),
        .cdb_tag(cdb_tag),
        .cdb_value(cdb_value)
    );

endmodule

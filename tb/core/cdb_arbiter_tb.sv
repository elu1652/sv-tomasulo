`timescale 1ns/1ps

module cdb_arbiter_tb;

    localparam int XLEN  = 32;
    localparam int TAG_W = 2;

    // Source 0: ALU
    logic             src0_valid;
    logic [TAG_W-1:0] src0_tag;
    logic [XLEN-1:0]  src0_value;
    logic             src0_ready;

    // Source 1: MUL
    logic             src1_valid;
    logic [TAG_W-1:0] src1_tag;
    logic [XLEN-1:0]  src1_value;
    logic             src1_ready;

    // Selected CDB output
    logic             cdb_valid;
    logic [TAG_W-1:0] cdb_tag;
    logic [XLEN-1:0]  cdb_value;

    cdb_arbiter #(
        .XLEN(XLEN),
        .TAG_W(TAG_W)
    ) dut (
        .src0_valid(src0_valid),
        .src0_tag(src0_tag),
        .src0_value(src0_value),
        .src0_ready(src0_ready),

        .src1_valid(src1_valid),
        .src1_tag(src1_tag),
        .src1_value(src1_value),
        .src1_ready(src1_ready),

        .cdb_valid(cdb_valid),
        .cdb_tag(cdb_tag),
        .cdb_value(cdb_value)
    );

    task automatic set_defaults;
        begin
            src0_valid = 1'b0;
            src0_tag   = '0;
            src0_value = '0;

            src1_valid = 1'b0;
            src1_tag   = '0;
            src1_value = '0;

            #1;
        end
    endtask

    initial begin
        $dumpfile("cdb_arbiter_tb.vcd");
        $dumpvars(0, cdb_arbiter_tb);

        set_defaults();

        // ------------------------------------------------------------
        // Test 1: no valid sources
        // ------------------------------------------------------------

        if (cdb_valid !== 1'b0) begin
            $display("ERROR: CDB should be invalid when no source is valid");
            $fatal;
        end

        if (src0_ready !== 1'b0 || src1_ready !== 1'b0) begin
            $display("ERROR: no source should be ready when none is valid");
            $fatal;
        end

        if (cdb_tag !== '0 || cdb_value !== '0) begin
            $display("ERROR: idle CDB outputs should be zero");
            $fatal;
        end

        $display("SUCCESS: no valid sources");

        // ------------------------------------------------------------
        // Test 2: source 0 only
        // ------------------------------------------------------------

        src0_valid = 1'b1;
        src0_tag   = 2'd1;
        src0_value = 32'd30;

        src1_valid = 1'b0;
        src1_tag   = 2'd2;
        src1_value = 32'd99;

        #1;

        if (cdb_valid !== 1'b1) begin
            $display("ERROR: CDB should be valid for source 0");
            $fatal;
        end

        if (cdb_tag !== 2'd1 || cdb_value !== 32'd30) begin
            $display(
                "ERROR: expected source 0 result ROB1=30, got ROB%0d=%0d",
                cdb_tag,
                cdb_value
            );
            $fatal;
        end

        if (src0_ready !== 1'b1 || src1_ready !== 1'b0) begin
            $display("ERROR: source 0 should be selected");
            $fatal;
        end

        $display("SUCCESS: source 0 selected");

        // ------------------------------------------------------------
        // Test 3: source 1 only
        // ------------------------------------------------------------

        src0_valid = 1'b0;
        src0_tag   = 2'd1;
        src0_value = 32'd30;

        src1_valid = 1'b1;
        src1_tag   = 2'd2;
        src1_value = 32'd50;

        #1;

        if (cdb_valid !== 1'b1) begin
            $display("ERROR: CDB should be valid for source 1");
            $fatal;
        end

        if (cdb_tag !== 2'd2 || cdb_value !== 32'd50) begin
            $display(
                "ERROR: expected source 1 result ROB2=50, got ROB%0d=%0d",
                cdb_tag,
                cdb_value
            );
            $fatal;
        end

        if (src0_ready !== 1'b0 || src1_ready !== 1'b1) begin
            $display("ERROR: source 1 should be selected");
            $fatal;
        end

        $display("SUCCESS: source 1 selected");

        // ------------------------------------------------------------
        // Test 4: both valid, source 0 wins fixed priority
        // ------------------------------------------------------------

        src0_valid = 1'b1;
        src0_tag   = 2'd1;
        src0_value = 32'd30;

        src1_valid = 1'b1;
        src1_tag   = 2'd2;
        src1_value = 32'd50;

        #1;

        if (cdb_valid !== 1'b1) begin
            $display("ERROR: CDB should be valid when both sources are valid");
            $fatal;
        end

        if (cdb_tag !== 2'd1 || cdb_value !== 32'd30) begin
            $display(
                "ERROR: source 0 should win priority, got ROB%0d=%0d",
                cdb_tag,
                cdb_value
            );
            $fatal;
        end

        if (src0_ready !== 1'b1 || src1_ready !== 1'b0) begin
            $display("ERROR: source 0 should win when both are valid");
            $fatal;
        end

        $display("SUCCESS: source 0 wins fixed priority");

        // ------------------------------------------------------------
        // Test 5: source 0 becomes invalid, source 1 gets the CDB
        // ------------------------------------------------------------

        src0_valid = 1'b0;

        #1;

        if (cdb_valid !== 1'b1) begin
            $display("ERROR: source 1 should use the CDB after source 0 clears");
            $fatal;
        end

        if (cdb_tag !== 2'd2 || cdb_value !== 32'd50) begin
            $display(
                "ERROR: expected delayed source 1 result ROB2=50, got ROB%0d=%0d",
                cdb_tag,
                cdb_value
            );
            $fatal;
        end

        if (src0_ready !== 1'b0 || src1_ready !== 1'b1) begin
            $display("ERROR: source 1 should now be selected");
            $fatal;
        end

        $display("SUCCESS: source 1 selected after source 0 clears");

        $display("CDB ARBITER TEST PASSED");
        $finish;
    end

endmodule

`timescale 1ns/1ps

module cdb_tb;

    localparam int XLEN      = 32;
    localparam int TAG_WIDTH = 3;

    logic                 fu_result_valid;
    logic [TAG_WIDTH-1:0] fu_result_tag;
    logic [XLEN-1:0]      fu_result_value;

    logic                 cdb_valid;
    logic [TAG_WIDTH-1:0] cdb_tag;
    logic [XLEN-1:0]      cdb_value;

    cdb #(
        .XLEN(XLEN),
        .TAG_WIDTH(TAG_WIDTH)
    ) dut (
        .fu_result_valid(fu_result_valid),
        .fu_result_tag(fu_result_tag),
        .fu_result_value(fu_result_value),

        .cdb_valid(cdb_valid),
        .cdb_tag(cdb_tag),
        .cdb_value(cdb_value)
    );

    task automatic drive_fu_result(
        input logic                 valid,
        input logic [TAG_WIDTH-1:0] tag,
        input logic [XLEN-1:0]      value
    );
        begin
            fu_result_valid = valid;
            fu_result_tag   = tag;
            fu_result_value = value;

            // CDB is combinational, so wait a tiny delay for outputs to settle.
            #1;
        end
    endtask

    task automatic expect_cdb(
        input logic                 expected_valid,
        input logic [TAG_WIDTH-1:0] expected_tag,
        input logic [XLEN-1:0]      expected_value
    );
        begin
            if (cdb_valid !== expected_valid) begin
                $display(
                    "ERROR: expected cdb_valid=%0b, got %0b",
                    expected_valid,
                    cdb_valid
                );
                $fatal;
            end

            if (cdb_tag !== expected_tag) begin
                $display(
                    "ERROR: expected cdb_tag=%0d, got %0d",
                    expected_tag,
                    cdb_tag
                );
                $fatal;
            end

            if (cdb_value !== expected_value) begin
                $display(
                    "ERROR: expected cdb_value=%0h, got %0h",
                    expected_value,
                    cdb_value
                );
                $fatal;
            end

            $display(
                "SUCCESS: CDB valid=%0b tag=%0d value=%0h",
                cdb_valid,
                cdb_tag,
                cdb_value
            );
        end
    endtask

    initial begin
        $dumpfile("cdb_tb.vcd");
        $dumpvars(0, cdb_tb);

        // No FU result available.
        drive_fu_result(1'b0, 3'd0, 32'h0000_0000);
        expect_cdb(1'b0, 3'd0, 32'h0000_0000);

        // FU broadcasts result for ROB2.
        drive_fu_result(1'b1, 3'd2, 32'h0000_1234);
        expect_cdb(1'b1, 3'd2, 32'h0000_1234);

        // FU broadcasts another result for ROB5.
        drive_fu_result(1'b1, 3'd5, 32'hdead_beef);
        expect_cdb(1'b1, 3'd5, 32'hdead_beef);

        // Valid drops, but tag/value wires still pass through.
        // Receivers should ignore tag/value when valid=0.
        drive_fu_result(1'b0, 3'd5, 32'hdead_beef);
        expect_cdb(1'b0, 3'd5, 32'hdead_beef);

        $display("CDB TEST PASSED");
        $finish;
    end

endmodule

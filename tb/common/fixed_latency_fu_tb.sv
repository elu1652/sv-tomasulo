`timescale 1ns/1ps

module fixed_latency_fu_tb;

    localparam int WIDTH     = 32;
    localparam int TAG_WIDTH = 3;
    localparam int LATENCY   = 3;

    logic                 clk;
    logic                 rst_n;
    logic                 start;
    logic [3:0]           op;
    logic [WIDTH-1:0]     operand_a;
    logic [WIDTH-1:0]     operand_b;
    logic [TAG_WIDTH-1:0] input_tag;

    logic                 busy;
    logic                 result_valid;
    logic [WIDTH-1:0]     result;
    logic [TAG_WIDTH-1:0] result_tag;

    fixed_latency_fu #(
        .WIDTH(WIDTH),
        .TAG_WIDTH(TAG_WIDTH),
        .LATENCY(LATENCY)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .op(op),
        .a(operand_a),
        .b(operand_b),
        .tag_in(input_tag),
        .busy(busy),
        .result_valid(result_valid),
        .result(result),
        .result_tag(result_tag)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic start_operation(
        input logic [3:0]           op_in,
        input logic [WIDTH-1:0]     a_in,
        input logic [WIDTH-1:0]     b_in,
        input logic [TAG_WIDTH-1:0] tag_in
    );
        begin
            @(negedge clk);

            if (busy) begin
                $display("ERROR: attempted to start while FU was busy");
                $fatal;
            end

            start     = 1'b1;
            op        = op_in;
            operand_a = a_in;
            operand_b = b_in;
            input_tag = tag_in;

            @(posedge clk);
            #1;

            start = 1'b0;
        end
    endtask

    task automatic wait_and_check_result(
        input logic [WIDTH-1:0]     expected_result,
        input logic [TAG_WIDTH-1:0] expected_tag
    );
        int elapsed_cycles;
        begin
            elapsed_cycles = 0;

            while (!result_valid) begin
                @(posedge clk);
                #1;
                elapsed_cycles++;
            end

            if (elapsed_cycles != LATENCY) begin
                $display(
                    "ERROR: expected latency %0d, observed %0d",
                    LATENCY,
                    elapsed_cycles
                );
                $fatal;
            end

            if (result !== expected_result) begin
                $display(
                    "ERROR: expected result %0d, got %0d",
                    expected_result,
                    result
                );
                $fatal;
            end

            if (result_tag !== expected_tag) begin
                $display(
                    "ERROR: expected tag %0d, got %0d",
                    expected_tag,
                    result_tag
                );
                $fatal;
            end

            $display(
                "SUCCESS: result=%0d tag=%0d latency=%0d",
                result,
                result_tag,
                elapsed_cycles
            );
        end
    endtask

    initial begin
        $dumpfile("fixed_latency_fu_tb.vcd");
        $dumpvars(0, fixed_latency_fu_tb);

        rst_n     = 1'b0;
        start     = 1'b0;
        op        = '0;
        operand_a = '0;
        operand_b = '0;
        input_tag = '0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        start_operation(
            4'd5,
            32'd6,
            32'd7,
            3'd4
        );

        if (!busy) begin
            $display("ERROR: FU should be busy after accepting operation");
            $fatal;
        end

        wait_and_check_result(
            32'd42,
            3'd4
        );

        @(posedge clk);
        #1;

        if (result_valid) begin
            $display("ERROR: result_valid should only stay high for one cycle");
            $fatal;
        end

        start_operation(
            4'd0,
            32'd10,
            32'd20,
            3'd6
        );

        wait_and_check_result(
            32'd30,
            3'd6
        );

        $display("FIXED LATENCY FU TEST PASSED");
        $finish;
    end

endmodule

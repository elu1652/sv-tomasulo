`timescale 1ns/1ps

module fifo_tb;

    localparam int WIDTH = 32;
    localparam int DEPTH = 4;
    localparam int COUNT_W = $clog2(DEPTH + 1);

    logic clk;
    logic rst_n;

    logic push_valid;
    logic push_ready;
    logic [WIDTH-1:0] push_data;

    logic pop_valid;
    logic pop_ready;
    logic [WIDTH-1:0] pop_data;

    logic [COUNT_W-1:0] count;

    fifo #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .push_valid(push_valid),
        .push_ready(push_ready),
        .push_data(push_data),

        .pop_valid(pop_valid),
        .pop_ready(pop_ready),
        .pop_data(pop_data),

        .count(count)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic reset_dut;
        begin
            rst_n = 1'b0;
            push_valid = 1'b0;
            push_data = '0;
            pop_ready = 1'b0;

            repeat(2) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;

            @(posedge clk);
            #1;

            if (count !== '0) begin
                $display("ERROR: count should be 0 after reset, but got %0d", count);
                $fatal;
            end

            if (pop_valid !== 1'b0) begin
                $display("ERROR: pop_valid should be 0 after reset, but got %b", pop_valid);
                $fatal;
            end

            if (push_ready !== 1'b1) begin
                $display("ERROR: push_ready should be 1 after reset, but got %b", push_ready);
                $fatal;
            end
        end
    endtask

    task automatic push_word(input logic [WIDTH-1:0] data);
        begin
            @(negedge clk);

            if (!push_ready) begin
                $display("ERROR: attempted to push when FIFO is full");
                $fatal;
            end

            push_valid = 1'b1;
            push_data = data;

            @(posedge clk);
            #1;

            push_valid = 1'b0;
            push_data = '0;
        end
    endtask

    task automatic pop_expect(input logic [WIDTH-1:0] expected);
        begin
            @(negedge clk);

            if (!pop_valid) begin
                $display("ERROR: attempted to pop when FIFO is empty");
                $fatal;
            end

            if (pop_data !== expected) begin
                $display("ERROR: expected pop_data=%0d, got %0d", expected, pop_data);
                $fatal;
            end

            pop_ready = 1'b1;

            @(posedge clk);
            #1;

            pop_ready = 1'b0;

            @(negedge clk);

            $display("SUCCESS: popped %0d", expected);
        end
    endtask

    task automatic check_count(input logic [COUNT_W-1:0] expected);
        begin
            #1;
            if (count !== expected) begin
                $display("ERROR: expected count=%0d, got %0d", expected, count);
                $fatal;
            end else begin
                $display("SUCCESS: count=%0d", count);
            end
        end
    endtask

    initial begin
        $dumpfile("fifo_tb.vcd");
        $dumpvars(0, fifo_tb);

        reset_dut();

        check_count(COUNT_W'(0));

        push_word(32'd10);
        check_count(COUNT_W'(1));

        push_word(32'd20);
        check_count(COUNT_W'(2));

        push_word(32'd30);
        check_count(COUNT_W'(3));

        pop_expect(32'd10);
        check_count(COUNT_W'(2));

        push_word(32'd40);
        check_count(COUNT_W'(3));

        push_word(32'd50);
        check_count(COUNT_W'(4));

        if (push_ready !== 1'b0) begin
            $display("ERROR: push_ready should be 0 when FIFO is full");
            $fatal;
        end

        pop_expect(32'd20);
        check_count(COUNT_W'(3));

        pop_expect(32'd30);
        check_count(COUNT_W'(2));

        pop_expect(32'd40);
        check_count(COUNT_W'(1));

        pop_expect(32'd50);
        check_count(COUNT_W'(0));

        if (pop_valid !== 1'b0) begin
            $display("ERROR: pop_valid should be 0 when FIFO is empty");
            $fatal;
        end

        $display("FIFO TEST PASSED");
        $finish;
    end

endmodule


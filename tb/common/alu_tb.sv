module alu_tb;

    localparam int WIDTH = 32;

    logic [3:0]       op;
    logic [WIDTH-1:0] a;
    logic [WIDTH-1:0] b;
    logic [WIDTH-1:0] result;
    logic             zero;

    localparam logic [3:0] ALU_ADD = 4'd0;
    localparam logic [3:0] ALU_SUB = 4'd1;
    localparam logic [3:0] ALU_AND = 4'd2;
    localparam logic [3:0] ALU_OR  = 4'd3;
    localparam logic [3:0] ALU_XOR = 4'd4;
    localparam logic [3:0] ALU_SLT = 4'd5;

    alu #(
        .WIDTH(WIDTH)
    ) dut (
        .op(op),
        .a(a),
        .b(b),
        .result(result),
        .zero(zero)
    );

    task check(
        input logic [3:0] op_in,
        input logic [WIDTH-1:0] a_in,
        input logic [WIDTH-1:0] b_in,
        input logic [WIDTH-1:0] expected
    );
        begin
            op = op_in;
            a = a_in;
            b = b_in;

            #1;

            if (result !== expected) begin
                $display("ERROR: op=%0d a=%0d b=%0d expected=%0d got=%0d",
                         op_in, a_in, b_in, expected, result);
                $fatal;
            end
        end
    endtask

    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);

        check(ALU_ADD, 32'd10, 32'd20, 32'd30);
        check(ALU_SUB, 32'd20, 32'd10, 32'd10);
        check(ALU_AND, 32'hF0F0, 32'h0FF0, 32'h00F0);
        check(ALU_OR,  32'hF0F0, 32'h0FF0, 32'hFFF0);
        check(ALU_XOR, 32'hF0F0, 32'h0FF0, 32'hFF00);

        check(ALU_SUB, 32'd10, 32'd10, 32'd0);

        if (zero !== 1'b1) begin
            $display("ERROR: zero flag should be 1");
            $fatal;
        end

        check(ALU_SLT, 32'd5, 32'd10, 32'd1);
        check(ALU_SLT, 32'd10, 32'd5, 32'd0);

        // signed test: -1 < 1 should be true
        check(ALU_SLT, 32'hFFFF_FFFF, 32'd1, 32'd1);

        $display("ALU TEST PASSED");
        $finish;
    end

endmodule

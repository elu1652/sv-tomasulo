module alu #(
    parameter int WIDTH = 32
) (
    input  logic [3:0]       op,
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    output logic [WIDTH-1:0] result,
    output logic             zero
);

    localparam logic [3:0] ALU_ADD = 4'd0;
    localparam logic [3:0] ALU_SUB = 4'd1;
    localparam logic [3:0] ALU_AND = 4'd2;
    localparam logic [3:0] ALU_OR  = 4'd3;
    localparam logic [3:0] ALU_XOR = 4'd4;
    localparam logic [3:0] ALU_SLT = 4'd5;

    always_comb begin
        unique case (op)
            ALU_ADD: result = a + b;
            ALU_SUB: result = a - b;
            ALU_AND: result = a & b;
            ALU_OR:  result = a | b;
            ALU_XOR: result = a ^ b;
            ALU_SLT: result = ($signed(a) < $signed(b)) ? {{(WIDTH-1){1'b0}}, 1'b1} : '0;
            default: result = '0;
        endcase
    end

    assign zero = (result == '0);

endmodule

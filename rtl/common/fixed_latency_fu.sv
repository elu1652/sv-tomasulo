`timescale 1ns/1ps
module fixed_latency_fu #(
    parameter  int WIDTH     = 32,
    parameter  int TAG_WIDTH = 3,
    parameter  int LATENCY   = 3,
    localparam int COUNT_W   = (LATENCY <= 1) ? 1 : $clog2(LATENCY + 1)

)(
    input  logic                 clk,
    input  logic                 rst_n,

    input  logic                 start,
    input  logic [3:0]           op,
    input  logic [WIDTH-1:0]     a,
    input  logic [WIDTH-1:0]     b,
    input  logic [TAG_WIDTH-1:0] tag_in,

    output logic                 busy,
    output logic                 result_valid,
    output logic [WIDTH-1:0]     result,
    output logic [TAG_WIDTH-1:0] result_tag
);

    logic [3:0]           op_reg;
    logic [WIDTH-1:0]     a_reg;
    logic [WIDTH-1:0]     b_reg;
    logic [TAG_WIDTH-1:0] tag_reg;
    logic [COUNT_W-1:0]  cycles_left;

    localparam logic [3:0] ALU_ADD = 4'd0;
    localparam logic [3:0] ALU_SUB = 4'd1;
    localparam logic [3:0] ALU_AND = 4'd2;
    localparam logic [3:0] ALU_OR  = 4'd3;
    localparam logic [3:0] ALU_XOR = 4'd4;
    localparam logic [3:0] ALU_MUL = 4'd5;

    logic [WIDTH-1:0]     computed_result;

    always_comb begin
        case (op_reg)
            ALU_ADD: computed_result = a_reg + b_reg;
            ALU_SUB: computed_result = a_reg - b_reg;
            ALU_AND: computed_result = a_reg & b_reg;
            ALU_OR:  computed_result = a_reg | b_reg;
            ALU_XOR: computed_result = a_reg ^ b_reg;
            ALU_MUL: computed_result = a_reg * b_reg;
            default: computed_result = 0;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            busy         <= 1'b0;
            result_valid <= 1'b0;
            result       <= '0;
            result_tag   <= '0;
            op_reg       <= '0;
            a_reg        <= '0;
            b_reg        <= '0;
            tag_reg      <= '0;
            cycles_left  <= '0;
        end else begin
            result_valid <= 1'b0;

            if(start && !busy) begin
                busy <= 1'b1;
                op_reg <= op;
                a_reg <= a;
                b_reg <= b;
                tag_reg <= tag_in;
                cycles_left <= COUNT_W'(LATENCY);
            end else if (busy) begin
                if (cycles_left == 1) begin
                    busy <= 1'b0;
                    result_valid <= 1'b1;
                    result <= computed_result;
                    result_tag <= tag_reg;
                    cycles_left <= '0;
                end else begin
                    cycles_left <= cycles_left - 1'b1;
                end
            end
        end
    end

endmodule



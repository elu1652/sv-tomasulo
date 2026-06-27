`timescale 1ns/1ps

module fifo #(
    parameter int WIDTH = 32,
    parameter int DEPTH = 4,
    localparam int ADDR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH),
    localparam int COUNT_W = $clog2(DEPTH + 1)
) (
    input logic clk,
    input logic rst_n,

    input logic push_valid,
    output logic push_ready,
    input logic [WIDTH-1:0] push_data,

    output logic pop_valid,
    input logic pop_ready,
    output logic [WIDTH-1:0] pop_data,

    output logic [COUNT_W-1:0] count
);

    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_W-1:0] head;
    logic [ADDR_W-1:0] tail;

    logic push_fire;
    logic pop_fire;

    assign push_ready = (count < COUNT_W'(DEPTH));
    assign pop_valid  = (count != '0);

    assign push_fire = push_valid && push_ready;
    assign pop_fire  = pop_valid && pop_ready;

    assign pop_data = mem[head];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head <= '0;
            tail <= '0;
            count <= '0;

            for (int i = 0; i < DEPTH; i++) begin
                mem[i] <= '0;
            end
        end else begin
            if (push_fire) begin
                mem[tail] <= push_data;

                if (tail == ADDR_W'(DEPTH-1)) begin
                    tail <= '0;
                end else begin
                    tail <= tail + 1'b1;
                end
            end

            if (pop_fire) begin
                if (head == ADDR_W'(DEPTH-1)) begin
                    head <= '0;
                end else begin
                    head <= head + 1'b1;
                end
            end

            case ({push_fire, pop_fire})
                2'b00: count <= count;
                2'b01: count <= count - 1'b1;
                2'b10: count <= count + 1'b1;
                2'b11: count <= count;
            endcase
        end
    end
endmodule


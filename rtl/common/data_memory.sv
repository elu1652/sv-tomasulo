`timescale 1ns/1ps

module data_memory #(
    parameter int XLEN = 32,
    parameter int NUM_WORDS = 64,
    localparam int ADDR_W = (NUM_WORDS <= 1) ? 1 : $clog2(NUM_WORDS)
) (
    input logic clk,
    input logic rst_n,

    // Read port
    input  logic [ADDR_W-1:0] read_addr,
    output logic [XLEN-1:0]   read_data,

    // Write port
    input logic              write_en,
    input logic [ADDR_W-1:0] write_addr,
    input logic [XLEN-1:0]   write_data
);

    logic [XLEN-1:0] mem [0:NUM_WORDS-1];

    assign read_data = mem[read_addr];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_WORDS; i++) begin
                mem[i] <= '0;
            end
        end else begin
            if (write_en) begin
                mem[write_addr] <= write_data;
            end
        end
    end

endmodule

module regfile #(
    parameter int WIDTH    = 32,
    parameter int NUM_REGS = 8,
    localparam int ADDR_W  = $clog2(NUM_REGS)
) (
    input logic clk,
    input logic rst_n,

    input  logic [ADDR_W-1:0] raddr1,
    input  logic [ADDR_W-1:0] raddr2,
    output logic [WIDTH-1:0]  rdata1,
    output logic [WIDTH-1:0]  rdata2,
    
    input logic              we,
    input logic [ADDR_W-1:0] waddr,
    input logic [WIDTH-1:0]  wdata
);

    logic [WIDTH-1:0] regs [0:NUM_REGS-1];

    integer i;

    // Async active-low reset and clocked writes
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_REGS; i++) begin
                regs[i] <= '0;
            end
        end else if (we && waddr != '0) begin
            regs[waddr] <= wdata;
        end
    end

    // Reads are combinational
    // Register 0 always reads 0
    always_comb begin
        rdata1 = (raddr1 == '0) ? '0 : regs[raddr1];
        rdata2 = (raddr2 == '0) ? '0 : regs[raddr2];
    end


endmodule
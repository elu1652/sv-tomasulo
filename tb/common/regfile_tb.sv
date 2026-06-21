`timescale 1ns/1ps

module regfile_tb;

    localparam int WIDTH    = 32;
    localparam int NUM_REGS = 8;
    localparam int ADDR_W   = $clog2(NUM_REGS);

    logic clk;
    logic rst_n;

    logic [ADDR_W-1:0]     raddr1;
    logic [ADDR_W-1:0]     raddr2;
    logic [WIDTH-1:0]      rdata1;
    logic [WIDTH-1:0]      rdata2;

    logic                  we;
    logic [ADDR_W-1:0]     waddr;
    logic [WIDTH-1:0]      wdata;

    regfile #(
        .WIDTH(WIDTH),
        .NUM_REGS(NUM_REGS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .raddr1(raddr1),
        .raddr2(raddr2),
        .rdata1(rdata1),
        .rdata2(rdata2),
        .we(we),
        .waddr(waddr),
        .wdata(wdata)
    );

    // Clock period = 10 ns
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic write_reg(
        input logic [ADDR_W-1:0] addr,
        input logic [WIDTH-1:0]  value
    );
        begin
            // Set inputs before next rising edge
            @(negedge clk);
            we = 1'b1;
            waddr = addr;
            wdata = value;

            // Write
            @(posedge clk);
            #1;

            we = 1'b0;
            waddr = '0;
            wdata = '0;
        end
    endtask

    task automatic check_reg(
        input logic [ADDR_W-1:0] address,
        input logic [WIDTH-1:0]  expected
    );
        begin
            raddr1 = address;
            #1;

            if (rdata1 !== expected) begin
                $display("ERROR: R%0d expected %0d, got %0d", address, expected, rdata1);
                $fatal;
            end else begin
                $display("SUCCESS: Register %0d has value %0h", address, rdata1);
            end
        end
    endtask

    initial begin
        $dumpfile("regfile_tb.vcd");
        $dumpvars(0, regfile_tb);

        rst_n = 1'b0;
        raddr1 = '0;
        raddr2 = '0;
        we = 1'b0;
        waddr = '0;
        wdata = '0;

        // Hold reset active for two clock edges
        repeat (2) @(posedge clk);

        rst_n = 1'b1;
        @(posedge clk);
        #1;

        // ALL registers should be 0 after reset
        check_reg(ADDR_W'(0), 32'd0);
        check_reg(ADDR_W'(1), 32'd0);
        check_reg(ADDR_W'(7), 32'd0);

        // Write some values.
        write_reg(3'd1, 32'd100);
        write_reg(3'd2, 32'd200);
        write_reg(3'd7, 32'hDEAD_BEEF);

        check_reg(3'd1, 32'd100);
        check_reg(3'd2, 32'd200);
        check_reg(3'd7, 32'hDEAD_BEEF);

        // Test both read ports simultaneously.
        raddr1 = 3'd1;
        raddr2 = 3'd2;
        #1;

        if (rdata1 !== 32'd100 || rdata2 !== 32'd200) begin
            $display(
                "ERROR: simultaneous read failed: rdata1=%0d rdata2=%0d",
                rdata1,
                rdata2
            );
            $fatal;
        end

        // Attempts to write R0 must be ignored.
        write_reg(3'd0, 32'd999);
        check_reg(3'd0, 32'd0);

        $display("REGISTER FILE TEST PASSED");
        $finish;
    end

endmodule

`timescale 1ns/1ps

module lsq_tb;

    localparam int NUM_ENTRIES = 4;
    localparam int XLEN        = 32;
    localparam int TAG_W       = 2;
    localparam int ADDR_W      = 6;

    localparam int INDEX_W =
        (NUM_ENTRIES <= 1) ? 1 : $clog2(NUM_ENTRIES);

    localparam int COUNT_W =
        $clog2(NUM_ENTRIES + 1);

    logic clk;
    logic rst_n;

    logic               alloc_valid;
    logic               alloc_ready;
    logic [INDEX_W-1:0] alloc_index;

    logic               alloc_is_store;
    logic [TAG_W-1:0]   alloc_rob_tag;
    logic [ADDR_W-1:0]  alloc_addr;
    logic [XLEN-1:0]    alloc_store_data;

    logic               retire_ready;
    logic               retire_valid;
    logic [INDEX_W-1:0] retire_index;

    logic              alloc_addr_ready;
    logic [TAG_W-1:0]  alloc_addr_tag;

    logic              alloc_data_ready;
    logic [TAG_W-1:0]  alloc_data_tag;

    logic              cdb_valid;
    logic [TAG_W-1:0]  cdb_tag;
    logic [XLEN-1:0]   cdb_value;

    logic               load_issue_valid;
    logic [INDEX_W-1:0] load_issue_index;
    logic [ADDR_W-1:0]  load_issue_addr;
    logic [TAG_W-1:0]   load_issue_rob_tag;

    logic [COUNT_W-1:0] count;

    lsq #(
        .NUM_ENTRIES(NUM_ENTRIES),
        .XLEN(XLEN),
        .TAG_W(TAG_W),
        .ADDR_W(ADDR_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .alloc_valid(alloc_valid),
        .alloc_ready(alloc_ready),
        .alloc_index(alloc_index),

        .alloc_is_store(alloc_is_store),
        .alloc_rob_tag(alloc_rob_tag),
        .alloc_addr(alloc_addr),
        .alloc_store_data(alloc_store_data),

        .retire_ready(retire_ready),
        .retire_valid(retire_valid),
        .retire_index(retire_index),

        .alloc_addr_ready(alloc_addr_ready),
        .alloc_addr_tag(alloc_addr_tag),

        .alloc_data_ready(alloc_data_ready),
        .alloc_data_tag(alloc_data_tag),

        .cdb_valid(cdb_valid),
        .cdb_tag(cdb_tag),
        .cdb_value(cdb_value),

        .load_issue_valid(load_issue_valid),
        .load_issue_index(load_issue_index),
        .load_issue_addr(load_issue_addr),
        .load_issue_rob_tag(load_issue_rob_tag),

        .count(count)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;

        alloc_valid      = 0;
        alloc_is_store   = 0;
        alloc_rob_tag    = '0;
        alloc_addr       = '0;
        alloc_store_data = '0;

        retire_ready = 0;

        alloc_addr_ready = 1'b1;
        alloc_addr_tag   = '0;

        alloc_data_ready = 1'b1;
        alloc_data_tag   = '0;

        cdb_valid = 1'b0;
        cdb_tag   = '0;
        cdb_value = '0;

        // Reset
        repeat (2) @(posedge clk);
        rst_n = 1;
        #1;

        if (count != 0)
            $fatal("LSQ should be empty after reset");

        if (!alloc_ready)
            $fatal("LSQ should accept allocation after reset");

        // -------------------------
        // Allocate entry 0
        // -------------------------

        @(negedge clk);

        alloc_valid      = 1;
        alloc_is_store   = 0;
        alloc_rob_tag    = 2'd0;
        alloc_addr       = 6'd10;
        alloc_store_data = 0;

        #1;

        if (alloc_index != 0)
            $fatal("First allocation should use entry 0");

        @(posedge clk);
        #1;

        alloc_valid = 0;

        if (count != 1)
            $fatal("Count should be 1");

        if (!retire_valid)
            $fatal("Oldest LSQ entry should be valid");

        if (retire_index != 0)
            $fatal("Head should point to entry 0");

        // -------------------------
        // Allocate entry 1
        // -------------------------

        @(negedge clk);

        alloc_valid      = 1;
        alloc_is_store   = 1;
        alloc_rob_tag    = 2'd1;
        alloc_addr       = 6'd20;
        alloc_store_data = 32'd99;

        #1;

        if (alloc_index != 1)
            $fatal("Second allocation should use entry 1");

        @(posedge clk);
        #1;

        alloc_valid = 0;

        if (count != 2)
            $fatal("Count should be 2");

        // -------------------------
        // Retire entry 0
        // -------------------------

        @(negedge clk);

        retire_ready = 1;

        @(posedge clk);
        #1;

        retire_ready = 0;

        if (count != 1)
            $fatal("Count should be 1 after retirement");

        if (retire_index != 1)
            $fatal("Head should advance to entry 1");

        // -------------------------
        // Retire entry 1
        // -------------------------

        @(negedge clk);

        retire_ready = 1;

        @(posedge clk);
        #1;

        retire_ready = 0;

        if (count != 0)
            $fatal("LSQ should be empty");

        if (retire_valid)
            $fatal("No entry should be valid after retiring everything");

        // -------------------------
        // Reset before wraparound test
        // -------------------------

        @(negedge clk);
        rst_n = 1'b0;

        @(posedge clk);
        #1;

        rst_n = 1'b1;

        if (count != 0)
            $fatal("LSQ should be empty after reset");

        // -------------------------
        // Circular wraparound test
        // -------------------------

        // Fill all 4 entries
        for (int i = 0; i < NUM_ENTRIES; i++) begin
            @(negedge clk);

            alloc_valid      = 1'b1;
            alloc_is_store   = 1'b0;
            alloc_rob_tag    = TAG_W'(i);
            alloc_addr       = ADDR_W'(10 + i);
            alloc_store_data = '0;

            #1;

            if (alloc_index != INDEX_W'(i))
                $fatal("Unexpected allocation index during fill");

            @(posedge clk);
            #1;

            alloc_valid = 1'b0;
        end

        if (count != NUM_ENTRIES)
            $fatal("LSQ should be full");

        if (alloc_ready)
            $fatal("LSQ should block allocation when full");

        // Retire first two entries
        for (int i = 0; i < 2; i++) begin
            @(negedge clk);

            retire_ready = 1'b1;

            @(posedge clk);
            #1;

            retire_ready = 1'b0;
        end

        if (count != 2)
            $fatal("Count should be 2 after two retirements");

        // Tail should now wrap around and allocate entry 0
        @(negedge clk);

        alloc_valid    = 1'b1;
        alloc_rob_tag  = 2'd0;
        alloc_addr     = 6'd50;

        #1;

        if (alloc_index != 0)
            $fatal("Tail should wrap to entry 0");

        @(posedge clk);
        #1;

        alloc_valid = 1'b0;

        // Next allocation should use entry 1
        @(negedge clk);

        alloc_valid    = 1'b1;
        alloc_rob_tag  = 2'd1;
        alloc_addr     = 6'd51;

        #1;

        if (alloc_index != 1)
            $fatal("Second wrapped allocation should use entry 1");

        @(posedge clk);
        #1;

        alloc_valid = 1'b0;

        if (count != NUM_ENTRIES)
            $fatal("LSQ should be full after wrapped allocations");

        // -------------------------
        // CDB wakeup test
        // -------------------------

        @(negedge clk);
        rst_n = 1'b0;

        @(posedge clk);
        #1;

        rst_n = 1'b1;

        // Allocate unresolved store
        @(negedge clk);

        alloc_valid      = 1'b1;
        alloc_is_store   = 1'b1;
        alloc_rob_tag    = 2'd0;

        alloc_addr       = '0;
        alloc_addr_ready = 1'b0;
        alloc_addr_tag   = 2'd1;

        alloc_store_data = '0;
        alloc_data_ready = 1'b0;
        alloc_data_tag   = 2'd2;

        @(posedge clk);
        #1;

        alloc_valid = 1'b0;

        if (dut.addr_ready[0])
            $fatal("Address should initially be unresolved");

        if (dut.data_ready[0])
            $fatal("Store data should initially be unresolved");

        @(negedge clk);

        cdb_valid = 1'b1;
        cdb_tag   = 2'd1;
        cdb_value = 32'd20;

        @(posedge clk);
        #1;

        cdb_valid = 1'b0;

        if (!dut.addr_ready[0])
            $fatal("Address should be ready after matching CDB broadcast");

        if (dut.address[0] != 6'd20)
            $fatal("Incorrect awakened address");

        if (dut.data_ready[0])
            $fatal("Store data should still be unresolved");

        @(negedge clk);

        cdb_valid = 1'b1;
        cdb_tag   = 2'd2;
        cdb_value = 32'd99;

        @(posedge clk);
        #1;

        cdb_valid = 1'b0;

        if (!dut.data_ready[0])
            $fatal("Store data should be ready after matching CDB broadcast");

        if (dut.store_data[0] != 32'd99)
            $fatal("Incorrect awakened store data");

        alloc_addr_ready = 1'b1;
        alloc_data_ready = 1'b1;

        // -------------------------
        // Load issue ordering tests
        // -------------------------

        @(negedge clk);
        rst_n = 1'b0;

        @(posedge clk);
        #1;

        rst_n = 1'b1;

        // -------------------------------------------------
        // Case 1: older store has unknown address -> BLOCK
        // -------------------------------------------------

        @(negedge clk);

        // Older store, address unresolved
        alloc_valid      = 1'b1;
        alloc_is_store   = 1'b1;
        alloc_rob_tag    = 2'd0;
        alloc_addr       = '0;
        alloc_addr_ready = 1'b0;
        alloc_addr_tag   = 2'd2;

        alloc_store_data = 32'd55;
        alloc_data_ready = 1'b1;

        @(posedge clk);
        #1;

        alloc_valid = 1'b0;

        @(negedge clk);

        // Younger load to address 20
        alloc_valid      = 1'b1;
        alloc_is_store   = 1'b0;
        alloc_rob_tag    = 2'd1;
        alloc_addr       = 6'd20;
        alloc_addr_ready = 1'b1;

        @(posedge clk);
        #1;

        alloc_valid = 1'b0;

        #1;

        if (load_issue_valid)
            $fatal("Load should be blocked by older store with unknown address");

        // -------------------------------------------------
        // Case 2: older store resolves to different address
        //         -> LOAD SAFE
        // -------------------------------------------------

        @(negedge clk);

        cdb_valid = 1'b1;
        cdb_tag   = 2'd2;
        cdb_value = 32'd10;

        @(posedge clk);
        #1;

        cdb_valid = 1'b0;

        #1;

        if (!load_issue_valid)
            $fatal(1, "Load should issue when older store has different address");

        if (load_issue_index != 1)
            $fatal(1, "Expected load in entry 1");

        if (load_issue_addr != 6'd20)
            $fatal(1, "Wrong load issue address");

        if (load_issue_rob_tag != 2'd1)
            $fatal(1, "Wrong load ROB tag");


        // -------------------------------------------------
        // Case 3: older store to same address -> BLOCK
        // -------------------------------------------------

        @(negedge clk);
        rst_n = 1'b0;

        @(posedge clk);
        #1;

        rst_n = 1'b1;

        @(negedge clk);

        // Older store to address 20
        alloc_valid      = 1'b1;
        alloc_is_store   = 1'b1;
        alloc_rob_tag    = 2'd0;
        alloc_addr       = 6'd20;
        alloc_addr_ready = 1'b1;

        alloc_store_data = 32'd99;
        alloc_data_ready = 1'b1;

        @(posedge clk);
        #1;

        alloc_valid = 1'b0;

        @(negedge clk);

        // Younger load also to address 20
        alloc_valid      = 1'b1;
        alloc_is_store   = 1'b0;
        alloc_rob_tag    = 2'd1;
        alloc_addr       = 6'd20;
        alloc_addr_ready = 1'b1;

        @(posedge clk);
        #1;

        alloc_valid = 1'b0;

        #1;

        if (load_issue_valid)
            $fatal("Load should be blocked by older same-address store");

        alloc_addr_ready = 1'b1;
        alloc_data_ready = 1'b1;
        cdb_valid        = 1'b0;

        $display("LSQ TEST PASSED");
        $finish;
    end

endmodule

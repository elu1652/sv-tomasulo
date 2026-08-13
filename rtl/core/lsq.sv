    `timescale 1ns/1ps

    module lsq #(
        parameter int NUM_ENTRIES = 4,
        parameter int XLEN  = 32,
        parameter int TAG_W = 2,
        parameter int ADDR_W = 6,

        localparam int INDEX_W =
            (NUM_ENTRIES <= 1) ? 1 : $clog2(NUM_ENTRIES),

        localparam int COUNT_W =
            $clog2(NUM_ENTRIES + 1)
    ) (
        input logic clk,
        input logic rst_n,

        // Add a new memory instruction
        input  logic               alloc_valid,
        output logic               alloc_ready,
        output logic [INDEX_W-1:0] alloc_index,

        input logic              alloc_is_store,
        input logic [TAG_W-1:0]  alloc_rob_tag,
        input logic [ADDR_W-1:0] alloc_addr,
        input logic [XLEN-1:0]   alloc_store_data,

        // Free an entry after commit
        input  logic retire_ready,
        output logic retire_valid,
        output logic [INDEX_W-1:0] retire_index,

        // CDB interface for address and data writeback
        input logic              alloc_addr_ready,
        input logic [TAG_W-1:0]  alloc_addr_tag,

        input logic              alloc_data_ready,
        input logic [TAG_W-1:0]  alloc_data_tag,

        input logic              cdb_valid,
        input logic [TAG_W-1:0]  cdb_tag,
        input logic [XLEN-1:0]   cdb_value,

        // Issue interface for load instructions
        output logic               load_issue_valid,
        output logic [INDEX_W-1:0] load_issue_index,
        output logic [ADDR_W-1:0]  load_issue_addr,
        output logic [TAG_W-1:0]   load_issue_rob_tag,


        // Number of occupied entries
        output logic [COUNT_W-1:0] count
    );

        logic valid [0:NUM_ENTRIES-1];

        logic [INDEX_W-1:0] head;
        logic [INDEX_W-1:0] tail;

        logic              is_store   [0:NUM_ENTRIES-1];
        logic [TAG_W-1:0]  rob_tag    [0:NUM_ENTRIES-1];
        logic [ADDR_W-1:0] address    [0:NUM_ENTRIES-1];
        logic [XLEN-1:0]   store_data [0:NUM_ENTRIES-1];

        logic              addr_ready [0:NUM_ENTRIES-1];
        logic [TAG_W-1:0]  addr_tag   [0:NUM_ENTRIES-1];

        logic              data_ready [0:NUM_ENTRIES-1];
        logic [TAG_W-1:0]  data_tag   [0:NUM_ENTRIES-1];

        logic alloc_fire;

        logic retire_fire;

        assign alloc_ready = (count < COUNT_W'(NUM_ENTRIES));

        assign alloc_fire = alloc_valid && alloc_ready;

        assign alloc_index = tail;

        assign retire_valid = valid[head];
        assign retire_index = head;
        assign retire_fire  = retire_valid && retire_ready;

        function automatic logic [INDEX_W-1:0] next_ptr(
            input logic [INDEX_W-1:0] ptr
        );
            begin
                if (ptr == INDEX_W'(NUM_ENTRIES - 1)) begin
                    next_ptr = '0;
                end else begin
                    next_ptr = ptr + 1'b1;
                end
            end
        endfunction

        always_comb begin
            load_issue_valid   = 1'b0;
            load_issue_index   = '0;
            load_issue_addr    = '0;
            load_issue_rob_tag = '0;

            // Search entries in program order starting from head
            for (int candidate_age = 0;
                candidate_age < NUM_ENTRIES;
                candidate_age++) begin

                logic [INDEX_W-1:0] candidate_idx;
                logic [INDEX_W-1:0] older_idx;
                logic safe;

                candidate_idx = head;

                // Move candidate_idx candidate_age positions from head
                for (int step = 0; step < candidate_age; step++) begin
                    candidate_idx = next_ptr(candidate_idx);
                end

                // Only consider occupied loads whose address is ready
                if (!load_issue_valid &&
                    candidate_age < count &&
                    valid[candidate_idx] &&
                    !is_store[candidate_idx] &&
                    addr_ready[candidate_idx]) begin

                    safe      = 1'b1;
                    older_idx = head;

                    // Examine everything older than this load
                    for (int older_age = 0;
                        older_age < candidate_age;
                        older_age++) begin

                        if (valid[older_idx] && is_store[older_idx]) begin

                            // Unknown older-store address:
                            // cannot prove this load is safe.
                            if (!addr_ready[older_idx]) begin
                                safe = 1'b0;
                            end

                            // Known older store to same address:
                            // block for now.
                            else if (address[older_idx] == address[candidate_idx]) begin
                                safe = 1'b0;
                            end
                        end

                        older_idx = next_ptr(older_idx);
                    end

                    if (safe) begin
                        load_issue_valid   = 1'b1;
                        load_issue_index   = candidate_idx;
                        load_issue_addr    = address[candidate_idx];
                        load_issue_rob_tag = rob_tag[candidate_idx];
                    end
                end
            end
        end

        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                head  <= '0;
                tail  <= '0;
                count <= '0;

                for (int i = 0; i < NUM_ENTRIES; i++) begin
                    valid[i] <= 1'b0;

                    addr_ready[i] <= 1'b0;
                    addr_tag[i]   <= '0;

                    data_ready[i] <= 1'b0;
                    data_tag[i]   <= '0;

                    is_store[i]   <= 1'b0;
                    rob_tag[i]    <= '0;
                    address[i]    <= '0;
                    store_data[i] <= '0;
                end

            end else begin

                if (alloc_fire) begin
                    valid[tail]      <= 1'b1;
                    is_store[tail]   <= alloc_is_store;
                    rob_tag[tail]    <= alloc_rob_tag;
                    address[tail]    <= alloc_addr;
                    store_data[tail] <= alloc_store_data;

                    addr_ready[tail] <= alloc_addr_ready;
                    addr_tag[tail]   <= alloc_addr_tag;

                    data_ready[tail] <= alloc_data_ready;
                    data_tag[tail]   <= alloc_data_tag;

                    tail <= next_ptr(tail);
                end

                if (retire_fire) begin
                    valid[head]      <= 1'b0;
                    is_store[head]   <= 1'b0;
                    rob_tag[head]    <= '0;
                    address[head]    <= '0;
                    store_data[head] <= '0;

                    addr_ready[head] <= 1'b0;
                    addr_tag[head]   <= '0;

                    data_ready[head] <= 1'b0;
                    data_tag[head]   <= '0;

                    head <= next_ptr(head);
                end

                if (cdb_valid) begin
                    for (int i = 0; i < NUM_ENTRIES; i++) begin
                        if (valid[i]) begin

                            if (!addr_ready[i] && addr_tag[i] == cdb_tag) begin
                                address[i]    <= cdb_value[ADDR_W-1:0];
                                addr_ready[i] <= 1'b1;
                            end

                            if (!data_ready[i] && data_tag[i] == cdb_tag) begin
                                store_data[i] <= cdb_value;
                                data_ready[i] <= 1'b1;
                            end

                        end
                    end
                end

                case ({alloc_fire, retire_fire})
                    2'b10: count <= count + 1'b1;
                    2'b01: count <= count - 1'b1;
                    default: count <= count;
                endcase

            end
        end

    endmodule

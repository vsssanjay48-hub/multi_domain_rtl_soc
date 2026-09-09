// =============================================================================
// Testbench: tb_cdc_async_fifo
// Description: Focused testbench for async FIFO CDC crossing
// License: MIT
// =============================================================================

`timescale 1ns / 1ps

module tb_cdc_async_fifo;

    localparam DATA_WIDTH = 8;
    localparam DEPTH = 16;

    // Clocks
    reg wr_clk = 0, rd_clk = 0;
    reg wr_rst_n = 0, rd_rst_n = 0;

    // Write interface
    reg [DATA_WIDTH-1:0] wr_data = 0;
    reg wr_en = 0;
    wire wr_full;

    // Read interface
    wire [DATA_WIDTH-1:0] rd_data;
    reg rd_en = 0;
    wire rd_empty;

    // DUT
    cdc_async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .SYNC_STAGES(2)
    ) dut (
        .wr_clk(wr_clk), .wr_rst_n(wr_rst_n),
        .wr_en(wr_en), .wr_data(wr_data), .wr_full(wr_full),
        .rd_clk(rd_clk), .rd_rst_n(rd_rst_n),
        .rd_en(rd_en), .rd_data(rd_data), .rd_empty(rd_empty)
    );

    // Incommensurate clocks (100 MHz write, 83 MHz read)
    always #5 wr_clk = ~wr_clk;
    always #6 rd_clk = ~rd_clk;

    integer pass_count = 0, fail_count = 0;
    integer i;

    initial begin
        $dumpvars(0, tb_cdc_async_fifo);

        wr_rst_n = 0; rd_rst_n = 0;
        #50 wr_rst_n = 1; rd_rst_n = 1;

        $display("\n=== CDC ASYNC FIFO TESTBENCH ===");

        // Test 1: Write and read back
        $display("\n[TEST 1] Write 8 values, read them back...");
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge wr_clk);
            wr_data = 8'hA0 + i;
            wr_en = 1;
        end
        wr_en = 0;

        // Wait for CDC latency
        repeat (10) @(posedge rd_clk);

        // Read back
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge rd_clk);
            if (!rd_empty) begin
                if (rd_data == (8'hA0 + i)) begin
                    $display("  [%0d] Read: 0x%h ✓", i, rd_data);
                    pass_count = pass_count + 1;
                end else begin
                    $display("  [%0d] Read: 0x%h ✗ Expected: 0x%h", i, rd_data, 8'hA0 + i);
                    fail_count = fail_count + 1;
                end
                rd_en = 1;
            end
        end
        rd_en = 0;

        // Test 2: FIFO full condition
        $display("\n[TEST 2] Fill FIFO to capacity...");
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(posedge wr_clk);
            if (!wr_full) begin
                wr_data = 8'h50 + i;
                wr_en = 1;
            end
        end
        wr_en = 0;

        if (wr_full) begin
            $display("  FIFO full flag asserted ✓");
            pass_count = pass_count + 1;
        end else begin
            $display("  FIFO full flag NOT asserted ✗");
            fail_count = fail_count + 1;
        end

        repeat (20) @(posedge wr_clk);

        $display("\n=== RESULTS ===");
        $display("  PASSED: %d", pass_count);
        $display("  FAILED: %d", fail_count);
        $display("=============");
        $finish;
    end

endmodule

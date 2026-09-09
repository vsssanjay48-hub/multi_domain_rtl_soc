// =============================================================================
// Module: soc_top
// Description: 5-independent master clock domain SoC with multi-bit CDC
//              - 5 master async clocks (unrelated frequencies)
//              - 1+ generated clock per master (dividers: /2, /3, /4, /5)
//              - Async FIFOs for inter-domain data transfer
//              - UART instances (1 per domain)
//              - CRC-32 datapath verification
//              - Priority arbiter (5-port round-robin)
//              - Register file with dual-port access
// License: MIT
// =============================================================================

`timescale 1ns / 1ps

module soc_top #(
    parameter FIFO_WIDTH = 8,
    parameter FIFO_DEPTH = 16,
    parameter NUM_DOMAINS = 5,
    parameter NUM_REGS = 32,
    parameter REG_WIDTH = 32
) (
    // Master clocks (async, unrelated frequencies)
    input  wire clk_master[NUM_DOMAINS-1:0],
    
    // Generated clocks (outputs from clock dividers)
    output wire clk_gen[NUM_DOMAINS-1:0],
    
    // Global reset (async active low)
    input  wire global_rst_n,
    
    // UART interfaces (1 per domain)
    input  wire [NUM_DOMAINS-1:0] uart_rx,
    output wire [NUM_DOMAINS-1:0] uart_tx,
    
    // Debug / status outputs
    output wire [31:0] fifo_status,      // FIFO full/empty flags
    output wire [31:0] arbiter_grant,    // Arbiter active grant
    output wire [31:0] crc_output        // Last CRC result
);

    // =========================================================================
    // Clock Generation: Create 1 derived clock per master using dividers
    // =========================================================================
    // Master 0 -> clk_gen[0] via ÷2
    clock_divider #(.DIVISOR(2)) div_0 (
        .clk_in(clk_master[0]), .clk_out(clk_gen[0])
    );
    
    // Master 1 -> clk_gen[1] via ÷3
    clock_divider #(.DIVISOR(3)) div_1 (
        .clk_in(clk_master[1]), .clk_out(clk_gen[1])
    );
    
    // Master 2 -> clk_gen[2] via ÷4
    clock_divider #(.DIVISOR(4)) div_2 (
        .clk_in(clk_master[2]), .clk_out(clk_gen[2])
    );
    
    // Master 3 -> clk_gen[3] via ÷5
    clock_divider #(.DIVISOR(5)) div_3 (
        .clk_in(clk_master[3]), .clk_out(clk_gen[3])
    );
    
    // Master 4 -> clk_gen[4] via ÷2
    clock_divider #(.DIVISOR(2)) div_4 (
        .clk_in(clk_master[4]), .clk_out(clk_gen[4])
    );

    // =========================================================================
    // Clock Domain Crossing FIFOs
    // Example: Master0 -> Master1 data transfer via async FIFO
    // =========================================================================
    wire [FIFO_WIDTH-1:0] fifo_wr_data_m0;
    wire fifo_wr_en_m0, fifo_wr_full_m0;
    wire [FIFO_WIDTH-1:0] fifo_rd_data_m1;
    wire fifo_rd_en_m1, fifo_rd_empty_m1;
    
    cdc_async_fifo #(
        .DATA_WIDTH(FIFO_WIDTH),
        .DEPTH(FIFO_DEPTH),
        .SYNC_STAGES(2)
    ) fifo_m0_to_m1 (
        // Write side (Master 0 domain)
        .wr_clk(clk_master[0]),
        .wr_rst_n(global_rst_n),
        .wr_en(fifo_wr_en_m0),
        .wr_data(fifo_wr_data_m0),
        .wr_full(fifo_wr_full_m0),
        // Read side (Master 1 domain)
        .rd_clk(clk_master[1]),
        .rd_rst_n(global_rst_n),
        .rd_en(fifo_rd_en_m1),
        .rd_data(fifo_rd_data_m1),
        .rd_empty(fifo_rd_empty_m1)
    );
    
    assign fifo_status[0] = fifo_wr_full_m0;
    assign fifo_status[1] = fifo_rd_empty_m1;

    // =========================================================================
    // UART Instances (one per master clock domain)
    // =========================================================================
    genvar i;
    generate
        for (i = 0; i < NUM_DOMAINS; i = i + 1) begin : uart_gen
            uart_core #(
                .FIFO_DEPTH(8),
                .CLKS_PER_BIT(8)  // Adjust for your clock speeds
            ) uart_inst (
                .clk(clk_master[i]),
                .rst_n(global_rst_n),
                .uart_rx_i(uart_rx[i]),
                .uart_tx_o(uart_tx[i]),
                .tx_data(),      // Tie off for now
                .tx_valid(),
                .tx_ready(),
                .rx_data(),
                .rx_valid()
            );
        end
    endgenerate

    // =========================================================================
    // CRC-32 Engine (in Master 0 domain)
    // Processes data from the FIFO crossing
    // =========================================================================
    wire crc_en_m0;
    wire [7:0] crc_data_m0;
    wire [31:0] crc_out_m0;
    
    crc32_engine u_crc (
        .clk(clk_master[0]),
        .rst_n(global_rst_n),
        .data_in(crc_data_m0),
        .data_valid(crc_en_m0),
        .crc_out(crc_out_m0)
    );
    
    assign crc_output = crc_out_m0;

    // =========================================================================
    // Register File (dual-port, with CDC for cross-domain reads)
    // =========================================================================
    wire [4:0] reg_addr_wr, reg_addr_rd;
    wire [REG_WIDTH-1:0] reg_data_in, reg_data_out;
    wire reg_we;
    
    register_file #(
        .NUM_REGS(NUM_REGS),
        .REG_WIDTH(REG_WIDTH)
    ) u_regfile (
        .clk(clk_master[0]),
        .rst_n(global_rst_n),
        .wr_addr(reg_addr_wr),
        .wr_data(reg_data_in),
        .wr_en(reg_we),
        .rd_addr(reg_addr_rd),
        .rd_data(reg_data_out)
    );

    // =========================================================================
    // Priority Arbiter (5 ports, one per master domain)
    // Round-robin arbitration for shared resource access
    // =========================================================================
    wire [NUM_DOMAINS-1:0] arb_request = 5'b00001;  // Placeholder: hardwire for now
    wire [NUM_DOMAINS-1:0] arb_acknowledge = 5'b00000;  // Placeholder
    wire [NUM_DOMAINS-1:0] arb_grant;
    wire arb_grant_valid;
    wire [2:0] arb_grant_encoded;
    
    arbiter #(
        .PORTS(NUM_DOMAINS),
        .ARB_TYPE_ROUND_ROBIN(1),
        .ARB_BLOCK(0),
        .ARB_BLOCK_ACK(1),
        .ARB_LSB_HIGH_PRIORITY(0)
    ) u_arb (
        .clk(clk_master[0]),  // Arbiter runs in Master 0 domain
        .rst(~global_rst_n),
        .request(arb_request),
        .acknowledge(arb_acknowledge),
        .grant(arb_grant),
        .grant_valid(arb_grant_valid),
        .grant_encoded(arb_grant_encoded)
    );
    
    assign arbiter_grant = {29'h0, arb_grant_encoded};

    // =========================================================================
    // CDC Synchronizers (single-bit flag examples)
    // Synchronize interrupt flags between domains
    // =========================================================================
    wire uart_rx_valid_m0, uart_rx_valid_m1_sync;
    
    cdc_synchronizer_2ff u_sync_uart_flag (
        .clk_dst(clk_master[1]),
        .rst_n(global_rst_n),
        .din(uart_rx_valid_m0),
        .dout(uart_rx_valid_m1_sync)
    );

    // =========================================================================
    // Integration point: Feed FIFO to CRC and back
    // =========================================================================
    always @(posedge clk_master[0]) begin
        if (!global_rst_n) begin
            crc_en_m0 <= 1'b0;
            crc_data_m0 <= 8'h00;
            fifo_wr_en_m0 <= 1'b0;
        end else begin
            // Simple test: read from FIFO, feed to CRC
            fifo_wr_en_m0 <= ~fifo_wr_full_m0;  // Push test data
            crc_en_m0 <= ~fifo_rd_empty_m1;     // CRC input from read side
        end
    end

endmodule

// =============================================================================
// Module: uart_core
// Description: Simple UART with integrated TX/RX FIFO
//              Baud rate configurable via CLKS_PER_BIT parameter
// License: MIT (based on freecores/uart16550 patterns)
// =============================================================================

`timescale 1ns / 1ps

module uart_core #(
    parameter FIFO_DEPTH = 8,
    parameter CLKS_PER_BIT = 8
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         uart_rx_i,
    output wire         uart_tx_o,
    input  wire [7:0]   tx_data,
    input  wire         tx_valid,
    output wire         tx_ready,
    output wire [7:0]   rx_data,
    output wire         rx_valid
);

    // TX path: data -> FIFO -> serializer
    reg [7:0] tx_fifo [FIFO_DEPTH-1:0];
    reg [2:0] tx_wr_ptr = 0, tx_rd_ptr = 0;
    wire tx_fifo_full = (tx_wr_ptr == tx_rd_ptr - 1);
    wire tx_fifo_empty = (tx_wr_ptr == tx_rd_ptr);

    // RX path: deserializer -> FIFO -> data
    reg [7:0] rx_fifo [FIFO_DEPTH-1:0];
    reg [2:0] rx_wr_ptr = 0, rx_rd_ptr = 0;
    wire rx_fifo_full = (rx_wr_ptr == rx_rd_ptr - 1);
    wire rx_fifo_empty = (rx_wr_ptr == rx_rd_ptr);

    // TX shift register
    reg [9:0] tx_shift = 10'b11111_11111;  // Idle state (1 start + 8 data + 1 stop)
    reg [3:0] tx_bit_cnt = 0;
    reg [31:0] tx_clk_cnt = 0;
    wire tx_bit_tick = (tx_clk_cnt == CLKS_PER_BIT - 1);

    // RX shift register
    reg [9:0] rx_shift = 10'b0;
    reg [3:0] rx_bit_cnt = 0;
    reg [31:0] rx_clk_cnt = 0;
    wire rx_bit_tick = (rx_clk_cnt == CLKS_PER_BIT - 1);

    assign tx_ready = !tx_fifo_full;
    assign rx_valid = !rx_fifo_empty;
    assign rx_data = rx_fifo[rx_rd_ptr];
    assign uart_tx_o = tx_shift[0];

    // TX FIFO write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_wr_ptr <= 0;
        end else if (tx_valid && !tx_fifo_full) begin
            tx_fifo[tx_wr_ptr] <= tx_data;
            tx_wr_ptr <= tx_wr_ptr + 1;
        end
    end

    // TX serializer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_shift <= 10'b11111_11111;
            tx_bit_cnt <= 0;
            tx_clk_cnt <= 0;
            tx_rd_ptr <= 0;
        end else begin
            if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
                tx_clk_cnt <= 0;
                if (tx_bit_cnt == 10) begin
                    tx_bit_cnt <= 0;
                    if (!tx_fifo_empty) begin
                        tx_shift <= {1'b1, tx_fifo[tx_rd_ptr], 1'b0};
                        tx_rd_ptr <= tx_rd_ptr + 1;
                    end else begin
                        tx_shift <= 10'b11111_11111;
                    end
                end else begin
                    tx_shift <= {1'b1, tx_shift[9:1]};
                    tx_bit_cnt <= tx_bit_cnt + 1;
                end
            end else begin
                tx_clk_cnt <= tx_clk_cnt + 1;
            end
        end
    end

    // RX deserializer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_shift <= 10'b0;
            rx_bit_cnt <= 0;
            rx_clk_cnt <= 0;
        end else begin
            if (rx_clk_cnt == CLKS_PER_BIT - 1) begin
                rx_clk_cnt <= 0;
                if (rx_bit_cnt == 10) begin
                    rx_bit_cnt <= 0;
                    if (!rx_fifo_full) begin
                        rx_wr_ptr <= rx_wr_ptr + 1;
                        rx_fifo[rx_wr_ptr] <= rx_shift[8:1];
                    end
                end else begin
                    rx_shift <= {uart_rx_i, rx_shift[9:1]};
                    rx_bit_cnt <= rx_bit_cnt + 1;
                end
            end else begin
                rx_clk_cnt <= rx_clk_cnt + 1;
            end
        end
    end

    // RX FIFO read
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_rd_ptr <= 0;
        end
        // Read triggered externally via control logic
    end

endmodule

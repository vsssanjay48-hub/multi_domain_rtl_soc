// =============================================================================
// Module: cdc_async_fifo
// Description: Dual-clock asynchronous FIFO using Gray-coded pointers
//              (from birdybro/cdc_primitives)
// License: MIT
// =============================================================================

`timescale 1ns / 1ps

module cdc_async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 16,
    parameter SYNC_STAGES = 2
) (
    // Write port
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  wr_full,

    // Read port
    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  rd_empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);
    localparam PTR_WIDTH = ADDR_WIDTH + 1;

    // Memory
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Binary to Gray code conversion
    function [PTR_WIDTH-1:0] bin2gray;
        input [PTR_WIDTH-1:0] bin;
        bin2gray = bin ^ (bin >> 1);
    endfunction

    // Write domain
    reg [PTR_WIDTH-1:0] wr_ptr = 0;
    wire [PTR_WIDTH-1:0] wr_ptr_gray;
    (* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] rd_gray_sync [0:SYNC_STAGES-1];
    integer i;

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n)
            wr_ptr <= {PTR_WIDTH{1'b0}};
        else if (wr_en && !wr_full)
            wr_ptr <= wr_ptr + 1'b1;
    end

    assign wr_ptr_gray = bin2gray(wr_ptr);

    always @(posedge wr_clk) begin
        if (wr_en && !wr_full)
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
    end

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            for (i = 0; i < SYNC_STAGES; i = i + 1)
                rd_gray_sync[i] <= {PTR_WIDTH{1'b0}};
        end else begin
            rd_gray_sync[0] <= rd_ptr_gray;
            for (i = 1; i < SYNC_STAGES; i = i + 1)
                rd_gray_sync[i] <= rd_gray_sync[i-1];
        end
    end

    assign wr_full = (wr_ptr_gray ==
        {~rd_gray_sync[SYNC_STAGES-1][PTR_WIDTH-1],
         ~rd_gray_sync[SYNC_STAGES-1][PTR_WIDTH-2],
          rd_gray_sync[SYNC_STAGES-1][PTR_WIDTH-3:0]});

    // Read domain
    reg [PTR_WIDTH-1:0] rd_ptr = 0;
    wire [PTR_WIDTH-1:0] rd_ptr_gray;
    (* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] wr_gray_sync [0:SYNC_STAGES-1];

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n)
            rd_ptr <= {PTR_WIDTH{1'b0}};
        else if (rd_en && !rd_empty)
            rd_ptr <= rd_ptr + 1'b1;
    end

    assign rd_ptr_gray = bin2gray(rd_ptr);
    assign rd_data = mem[rd_ptr[ADDR_WIDTH-1:0]];

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            for (i = 0; i < SYNC_STAGES; i = i + 1)
                wr_gray_sync[i] <= {PTR_WIDTH{1'b0}};
        end else begin
            wr_gray_sync[0] <= wr_ptr_gray;
            for (i = 1; i < SYNC_STAGES; i = i + 1)
                wr_gray_sync[i] <= wr_gray_sync[i-1];
        end
    end

    assign rd_empty = (rd_ptr_gray == wr_gray_sync[SYNC_STAGES-1]);

endmodule

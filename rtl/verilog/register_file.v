// =============================================================================
// Module: register_file
// Description: Parameterizable dual-port register bank
//              Supports independent read and write addresses
// License: MIT
// =============================================================================

`timescale 1ns / 1ps

module register_file #(
    parameter NUM_REGS = 32,
    parameter REG_WIDTH = 32
) (
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [$clog2(NUM_REGS)-1:0] wr_addr,
    input  wire [REG_WIDTH-1:0]   wr_data,
    input  wire                   wr_en,
    input  wire [$clog2(NUM_REGS)-1:0] rd_addr,
    output wire [REG_WIDTH-1:0]   rd_data
);

    reg [REG_WIDTH-1:0] regs [NUM_REGS-1:0];
    integer i;

    // Initialize to zero
    initial begin
        for (i = 0; i < NUM_REGS; i = i + 1)
            regs[i] = {REG_WIDTH{1'b0}};
    end

    // Write port
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_REGS; i = i + 1)
                regs[i] <= {REG_WIDTH{1'b0}};
        end else if (wr_en) begin
            regs[wr_addr] <= wr_data;
        end
    end

    // Read port (combinational)
    assign rd_data = regs[rd_addr];

endmodule

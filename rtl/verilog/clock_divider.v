// =============================================================================
// Module: clock_divider
// Description: Parameterizable clock divider (even and odd divisors)
// License: MIT
// =============================================================================

`timescale 1ns / 1ps

module clock_divider #(
    parameter DIVISOR = 2
) (
    input  wire clk_in,
    output wire clk_out
);

    reg [31:0] counter = 0;
    reg clk_div = 0;

    always @(posedge clk_in) begin
        if (counter == DIVISOR - 1) begin
            counter <= 0;
            clk_div <= ~clk_div;
        end else begin
            counter <= counter + 1;
        end
    end

    assign clk_out = clk_div;

endmodule

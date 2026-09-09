// =============================================================================
// Module: priority_encoder
// Description: Priority encoder for arbiter request handling
// License: MIT
// =============================================================================

`timescale 1ns / 1ps

module priority_encoder #(
    parameter WIDTH = 4,
    parameter LSB_HIGH_PRIORITY = 0
) (
    input  wire [WIDTH-1:0] input_unencoded,
    output wire             output_valid,
    output wire [$clog2(WIDTH)-1:0] output_encoded,
    output wire [WIDTH-1:0] output_unencoded
);

    wire [WIDTH-1:0] valid = input_unencoded;
    assign output_valid = |valid;

    generate
        if (LSB_HIGH_PRIORITY == 0) begin : msb_priority
            // MSB has highest priority
            always @(*) begin : msb_encode
                integer i;
                output_encoded = 0;
                output_unencoded = 0;
                for (i = WIDTH - 1; i >= 0; i = i - 1) begin
                    if (valid[i]) begin
                        output_encoded = i;
                        output_unencoded[i] = 1'b1;
                    end
                end
            end
        end else begin : lsb_priority
            // LSB has highest priority
            always @(*) begin : lsb_encode
                integer i;
                output_encoded = 0;
                output_unencoded = 0;
                for (i = 0; i < WIDTH; i = i + 1) begin
                    if (valid[i]) begin
                        output_encoded = i;
                        output_unencoded[i] = 1'b1;
                    end
                end
            end
        end
    endgenerate

endmodule

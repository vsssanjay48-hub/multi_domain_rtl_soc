// =============================================================================
// Module: cdc_synchronizer_2ff
// Description: 2-flop synchronizer for single-bit level crossing
//              (from yeshvanth-m/digital-vlsi-design-tools)
// License: MIT
// =============================================================================

`timescale 1ns / 1ps

module cdc_synchronizer_2ff #(
    parameter STAGES = 2
) (
    input  wire clk_dst,
    input  wire rst_n,
    input  wire din,
    output wire dout
);

    reg [STAGES-1:0] sync;

    always @(posedge clk_dst or negedge rst_n)
        if (!rst_n)
            sync <= {STAGES{1'b0}};
        else
            sync <= {sync[STAGES-2:0], din};

    assign dout = sync[STAGES-1];

endmodule

// =============================================================================
// Module: cdc_handshake
// Description: Multi-bit handshake CDC (4-phase req/ack)
// =============================================================================

module cdc_handshake #(
    parameter WIDTH = 32
) (
    // Source clock domain
    input  wire             src_clk,
    input  wire [WIDTH-1:0] src_in,
    input  wire             src_send,
    output reg              src_rcv,

    // Destination clock domain
    input  wire             dest_clk,
    output reg  [WIDTH-1:0] dest_out,
    output reg              dest_req
);

    reg [WIDTH-1:0] src_latch;
    reg             src_req;
    (* ASYNC_REG = "TRUE" *) reg src_ack_ff1, src_ack_ff2;
    reg src_ack_prev;

    (* ASYNC_REG = "TRUE" *) reg dest_req_ff1, dest_req_ff2;
    reg dest_req_prev;
    reg dest_ack;

    // Source domain: latch data and create request
    always @(posedge src_clk) begin
        if (src_send) src_latch <= src_in;
        src_req <= src_send;
        src_ack_ff1 <= dest_ack;
        src_ack_ff2 <= src_ack_ff1;
        src_ack_prev <= src_ack_ff2;
        src_rcv <= src_ack_ff2 && !src_ack_prev;
    end

    // Destination domain: sync request, latch data, create ack
    always @(posedge dest_clk) begin
        dest_req_ff1 <= src_req;
        dest_req_ff2 <= dest_req_ff1;
        dest_req_prev <= dest_req_ff2;
        if (dest_req_ff2 != dest_req_prev) begin
            dest_out <= src_latch;
            dest_req <= 1'b1;
        end else begin
            dest_req <= 1'b0;
        end
        dest_ack <= dest_req_ff2;
    end

endmodule

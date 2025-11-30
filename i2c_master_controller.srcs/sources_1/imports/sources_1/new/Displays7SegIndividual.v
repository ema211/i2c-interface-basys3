`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ITESO
// Engineer: Ema
// Create Date: 24.09.2025 21:56:10
//////////////////////////////////////////////////////////////////////////////////

module Displays7SegIndividual(
    input [3:0] D0,
    input [3:0] D1,
    input [3:0] D2,
    input [3:0] D3,
    input rst,
    input clk,
    output [6:0] Seg,
    output [3:0] T
);

    wire [1:0] SelMux_w;
    wire [3:0] OutMux_w;

     Mux4bits4a1 Mux4bits4a1_i (
        .A_mux(D0),
        .B_mux(D1),
        .C_mux(D2),
        .D_mux(D3),
        .Sel_mux(SelMux_w),
        .Out_mux(OutMux_w)
    );

OneCold OneCold_i (
  . a_OC(SelMux_w[0]),
  . b_OC(SelMux_w[1]),
  .T(T)
);

    Display7Segmentos Display7Segmentos_i (
        .w(OutMux_w[3]),
        .x(OutMux_w[2]),
        .y(OutMux_w[1]),
        .z(OutMux_w[0]),
        .a(Seg[0]),
        .b(Seg[1]),
        .c(Seg[2]),
        .d(Seg[3]),
        .e(Seg[4]),
        .f(Seg[5]),
        .g(Seg[6])
    );

    Delayer_Counter #(.n(2), .width(20), .YY(100_000)) Delayer_Counter_i (
        .clk(clk),
        .rst(rst),
        .enable(1'b1),
        .q(SelMux_w)
    );
endmodule

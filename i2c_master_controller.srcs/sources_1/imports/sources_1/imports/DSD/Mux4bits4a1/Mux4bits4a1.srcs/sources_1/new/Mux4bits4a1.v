`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ITESO
// Engineer: Ema
// Create Date: 22.09.2025 12:32:03
//////////////////////////////////////////////////////////////////////////////////


module Mux4bits4a1(
    input [3:0] A_mux,
    input [3:0] B_mux,
    input [3:0] C_mux,
    input [3:0] D_mux,
    input [1:0] Sel_mux,
    output [3:0] Out_mux
    );

    assign Out_mux = (Sel_mux == 2'b00) ? A_mux :
                     (Sel_mux == 2'b01) ? B_mux :
                     (Sel_mux == 2'b10) ? C_mux : D_mux;
endmodule

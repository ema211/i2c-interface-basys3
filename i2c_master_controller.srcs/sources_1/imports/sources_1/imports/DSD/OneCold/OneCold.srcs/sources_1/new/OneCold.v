`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ITESO
// Engineer: Ema
// Create Date: 24.09.2025 10:30:06
//////////////////////////////////////////////////////////////////////////////////


module OneCold(
    input  a_OC,   // Sel[0]
    input  b_OC,   // Sel[1]
    output [3:0] T // activo-bajo (one-cold)
);
    assign T[0] =  a_OC |  b_OC;   // Sel=00 → 1110
    assign T[1] = ~a_OC |  b_OC;   // Sel=01 → 1101
    assign T[2] =  a_OC | ~b_OC;   // Sel=10 → 1011
    assign T[3] = ~a_OC | ~b_OC;   // Sel=11 → 0111
endmodule

`timescale 1ns / 1ps
// Company: ITESO
// Engineer: Cuauhtemoc Aguilera
//////////////////////////////////////////////////////////////////////////////////

module Debouncer #(parameter width = 22, parameter yy = 3_000_000)
  ( input clk,
    input rst,
    input sw,
    output one_shot
    );
    
wire fin_delay_w;
wire rst_Delayer_w;

Debouncer_FSM fsm_deboun_i (
  .clk(clk), 
  .fin_delay(fin_delay_w), 
  .rst(rst), 
  .sw(sw),
  .one_shot(one_shot), 
  .rst_Delayer (rst_Delayer_w)    
);

// Se requieren 22 bits para representar 3 millones de cuentas
Delayer # (.width(width), .YY(yy) ) delay30ms_i (
  .clk(clk), 
  .rst(rst_Delayer_w), 
  .enable(1'b1), 
  .iguales(fin_delay_w)
);


endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ITESO
// Engineer: Emanuel Aldana
// Create Date: 24.11.2025 15:09:39
// Module Name: clock_generator
// Description: Divisor de frecuencia parametrizable
// Additional Comments: Evitar frecuencias mayores a 50MHz
//////////////////////////////////////////////////////////////////////////////////


module clock_generator #( parameter FRECUENCIA = 100_000)(
    input reset,
    input clk_input,
    output reg clk_output
    );

    localparam integer DIVISOR = 100_000_000 / (FRECUENCIA * 2);

    localparam integer ANCHO_CUENTA = $clog2(DIVISOR + 1);
    reg [ANCHO_CUENTA-1:0] counter = 0;

    always @(posedge clk_input or posedge reset) begin
        if(reset) begin
            counter <= 0;
            clk_output <= 1'b0;
        end
        else 
            if(counter == DIVISOR) begin
                counter <= 0;
                clk_output <= ~clk_output;    // toggle reg
            end
            else
                counter <= counter + 1;
    end
endmodule

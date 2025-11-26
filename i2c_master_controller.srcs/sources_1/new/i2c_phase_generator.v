`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ITESO
// Engineer: Emanuel Aldana
// Create Date: 26.11.2025 10:22:05
// Module Name: i2c_phase_generator
// Description: Generador de fases para el controlador I2C
// Additional Comments: Evitar frecuencias mayores a 50MHz
//////////////////////////////////////////////////////////////////////////////////

module i2c_phase_generator #( parameter FRECUENCIA = 100_000)(
    input               reset,
    input               clk_input,
    output reg  [1:0]   phase
    );

    localparam integer DIVISOR = 100_000_000 / (FRECUENCIA * 4);

    localparam integer ANCHO_CUENTA = $clog2(DIVISOR + 1);
    reg [ANCHO_CUENTA-1:0] counter = 0;

    always @(posedge clk_input , posedge reset) begin
        if(reset) begin
            counter <= 0;
            phase <= 2'b00;
        end
        else begin
            if (counter == DIVISOR-1) begin
                counter <= 0;
                // avanzar fase 0→1→2→3→0
                if (phase == 2'b11)
                    phase <= 2'b00;
                else
                    phase <= phase + 2'b01;
            end else begin
                counter <= counter + 1;
            end
        end
    end
endmodule

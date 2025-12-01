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
    input               enable,
    output reg          tick,
    output reg         tick_end,
    output reg  [1:0]   phase
    );

    localparam integer DIVISOR = 100_000_000 / (FRECUENCIA * 4);

    localparam integer ANCHO_CUENTA = $clog2(DIVISOR + 1);
    reg [ANCHO_CUENTA-1:0] counter = 0;
    always @(posedge clk_input or posedge reset) begin
        if (reset || !enable) begin
            counter  <= 0;
            phase    <= 2'b00;
            tick     <= 1'b0;
            tick_end <= 1'b0;
        end else begin
            if (counter == DIVISOR-1) begin
                // Fin de la fase actual
                //Reinicia contador y avanza fase
                counter  <= 0;
                tick     <= 1'b1;   // inicio de nueva fase
                tick_end <= 1'b0;

                if (phase == 2'b11)
                    phase <= 2'b00;
                else
                    phase <= phase + 2'b01;
            end else begin
                // Ciclo normal dentro de la fase
                counter  <= counter + 1;
                tick     <= 1'b0;

                // tick_end en el penúltimo ciclo
                if (counter == DIVISOR-2)
                    tick_end <= 1'b1;
                else
                    tick_end <= 1'b0;
            end
        end
    end
endmodule

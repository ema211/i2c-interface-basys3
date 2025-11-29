`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.11.2025 14:39:57
// Design Name: 
// Module Name: i2c_core_test
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module i2c_core_test(
    input  wire clk,          // Reloj 100MHz (W5)
    
    // --- BUS PARALELO DE ENTRADA (PMOD JB) ---
    // El ESP escribe aquí el dato a enviar
    input  wire [7:0] bus_data_in, 
    
    // --- BUS PARALELO DE SALIDA (PMOD JC) ---
    // La FPGA escribe aquí el dato leído para que el ESP lo vea
    output wire [7:0] bus_data_out,
    
    // --- SEÑALES DE CONTROL (PMOD JA [0:3]) ---
    input  wire ctrl_start,
    input  wire ctrl_stop,
    input  wire ctrl_rw,
    input  wire ctrl_reset,
    
    // --- SEÑALES DE ESTADO (PMOD JA [4:5]) ---
    output wire status_busy,
    output wire status_done,
    output wire status_error, // (Opcional, si te sobra un pin)
    
    // --- I2C FÍSICO (PMOD JA [6:7] -> Pines reales JA9, JA10) ---
    inout  wire i2c_sda,
    output wire i2c_scl
    );

    // Dirección fija del sensor BH1750 (ADDR a GND)
    wire [6:0] fixed_slave_addr = 7'h23;

    // Instancia del Core Maestro
    i2c_core #(.F_SCL(100_000)) soc_i2c_unit (
        .clk_system(clk),
        .reset(ctrl_reset),
        
        // I2C Físico
        .sda(i2c_sda),
        .scl(i2c_scl),
        
        // Control desde el ESP
        .start(ctrl_start),
        .stop(ctrl_stop),
        .rw(ctrl_rw),
        
        // Datos desde el ESP (Bus JB)
        .data_in(bus_data_in), 
        
        // Dirección (Hardcodeada para ahorrar pines)
        .slave_address(fixed_slave_addr),
        
        // Feedback al ESP
        .busy(status_busy),
        .done(status_done),
        .ack_error(status_error),
        
        // Datos hacia el ESP (Bus JC)
        .data_out(bus_data_out)
    );

endmodule
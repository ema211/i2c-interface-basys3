`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ITESO
// Engineer: Emanuel Aldana
// Create Date: 25.11.2025 16:10:06
// Module Name: i2c_core 
// Description: 
// Additional Comments:
//////////////////////////////////////////////////////////////////////////////////



module i2c_core#(parameter integer F_SCL = 100_000)(
    // Reloj y reset
    input  wire        reset,
    input  wire        clk_system,

    // Líneas I2C físicas
    inout  wire        sda,          // entrada/salida de datos
    output wire        scl,          // el core genera SCL

    // Entradas de control (tipo registros de control)
    input  wire        start,        // petición de START / RESTART
    input  wire        stop,         // petición de STOP
    input  wire        rw,           // 0 = write, 1 = read
    input  wire [7:0]  data_in,      // byte a enviar (registro o dato)
    input  wire [7:0]  slave_address,// dirección del esclavo (SLA)

    // Salidas de estado
    output reg         busy,
    output reg         done,
    output reg         ack_error,
    output reg [7:0]   data_out
    );

    // Contador de bits (de 7 a 0)
    reg [2:0] bit_cnt;

    // Registros internos para dirección y datos
    reg [7:0] dr_reg;

    // Tri-state para SDA
    reg  sda_out_reg;
    reg  sda_oe_reg;
    wire sda_in;

    reg  scl_reg;

    assign sda    = sda_oe_reg ? sda_out_reg : 1'bz;
    assign sda_in = sda;

    assign scl = scl_reg;

    /*
    Reloj (100MHz):  _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_

    Phase (Lento):   ________0000000000________1111111111________2222222222_______
                    (Dura muchos ciclos)

    Phase == 00:     TTTTTTTTTT (Verdadero durante muchos ciclos )

    Phase_Tick:      _________________Λ__________________________Λ__________________
                    (Solo 1 ciclo)   ^                          ^
                                     |                          |
                            "¡Cambié a 01!"             "¡Cambié a 10!"
    */

    wire [1:0]  phase;        // fase 0–3 generada por i2c_phase_generator
    wire phase_tick;
    i2c_phase_generator #(.FRECUENCIA(F_SCL)) phase_gen (
        .reset    (reset),
        .clk_input(clk_system),
        .enable   (busy),
        .tick     (phase_tick),
        .phase    (phase)
    );

    //Definición de estados de la FSM principal
    localparam [3:0]
        ST_IDLE       = 4'd0,
        ST_START      = 4'd1,
        ST_ADDRRW     = 4'd2,
        ST_SLV_ACK1   = 4'd3,
        ST_WR         = 4'd4,
        ST_SLV_ACK2   = 4'd5,
        ST_RD         = 4'd6,
        ST_MASTER_ACK = 4'd7,
        ST_NACK_ERROR = 4'd8,
        ST_STOP       = 4'd9;

    reg [3:0] state;

    // Lógica secuencial para la transición de estados y salidas
    always @(posedge clk_system or posedge reset) begin

        if (reset) begin
            busy <= 1'b0;
            done <= 1'b0;
            ack_error <= 1'b0;
            data_out <= 0;
            bit_cnt <= 3'd0;
            sda_oe_reg  <= 1'b0;
            state <= ST_IDLE;
        end
        else begin
            case (state)

                ST_IDLE: begin
                    busy      <= 1'b0;
                    done      <= 1'b0;
                    ack_error <= 1'b0;   
                    data_out  <= 0;
                    bit_cnt   <= 3'd0;
                    sda_oe_reg <= 1'b0;

                    if (start) begin
                        busy <= 1'b1;
                        done <= 1'b0;
                        bit_cnt <= 3'd7;
                        dr_reg <= {slave_address, rw}; // Concatenar dirección y bit R/W
                        state <= ST_START;
                    end
                end

                ST_START: begin
                    sda_oe_reg <= 1'b1;
                    if (phase_tick) begin
                        if (phase == 2'b00) sda_oe_reg <= 1'b1;
                        if (phase == 2'b11) state <= ST_ADDRRW;
                    end
                end

                ST_ADDRRW: begin
                    if (phase_tick) begin   
                        if (phase == 2'b00) sda_oe_reg <= 1'b1; 

                        if (phase == 2'b11) begin
                            if (bit_cnt == 0) begin   
                                state <= ST_SLV_ACK1;
                            end else 
                                bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                ST_SLV_ACK1: begin
                    if (phase_tick) begin
                        if (phase == 2'b00) sda_oe_reg <= 1'b0; // Liberar SDA para ACK del esclavo
                        if (phase == 2'b10) ack_error <= sda_in; // Guardar ACK/NACK recibido
                        if (phase == 2'b11) begin  

                            if (ack_error == 1'b0) begin // ACK recibido
                                if (rw == 1'b0) begin
                                    dr_reg <= data_in;
                                    sda_oe_reg <= 1'b1;
                                    bit_cnt <= 3'd7;
                                    state <= ST_WR;
                                end else begin
                                    bit_cnt <= 3'd7;
                                    state <= ST_RD;
                                end
                            end else begin // NACK recibido
                                sda_oe_reg <= 1'b1;
                                sda_oe_reg <= 1'b1;
                                state <= ST_NACK_ERROR;
                            end
                    end
                    end
                end

                ST_WR: begin
                    if (phase_tick) begin
                        if (phase == 2'b00) sda_oe_reg <= 1'b1;
                          // setup del bit
                        if (phase == 2'b11) begin
                            if (bit_cnt == 0) begin   
                                state <= ST_SLV_ACK2;
                            end else 
                                bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                ST_SLV_ACK2: begin
                    if (phase_tick) begin
                        if (phase == 2'b00) sda_oe_reg <= 1'b0; 
                        if (phase == 2'b10) ack_error <= sda_in;   
                        if (phase == 2'b11) begin
                            sda_oe_reg <= 1'b1;
                            if (ack_error == 1'b0) begin 
                                if (stop) begin
                                    state <= ST_STOP;
                                end else if (start) begin
                                    bit_cnt <= 3'd7;
                                    sda_oe_reg  <= 1'b1;
                                    dr_reg <= {slave_address, rw}; 
                                    state <= ST_START;
                                end else begin
                                    dr_reg <= data_in;
                                    bit_cnt <= 3'd7;
                                    state <= ST_WR; 
                                end
                            end else begin // NACK recibido
                                state <= ST_NACK_ERROR;
                            end
                        end
                    end
                end

                ST_RD: begin
                    if (phase_tick) begin
                        if (phase == 2'b01) sda_oe_reg <= 1'b0; 

                        if (phase == 2'b10) dr_reg[bit_cnt] <= sda_in; 

                        if (phase == 2'b11) begin
                            sda_oe_reg <= 1'b1;
                            if (bit_cnt == 0) begin
                                data_out <= dr_reg; 
                                state <= ST_MASTER_ACK;
                            end else 
                                bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                ST_MASTER_ACK: begin
                    if (phase_tick) begin
                        
                        if (phase == 2'b00) sda_oe_reg <= 1'b1; 

                        if (phase == 2'b11) begin
                            
                            if (stop) begin
                                state <= ST_STOP;
                            end 
                            
                            else if (start) begin
                                state      <= ST_START;
                                dr_reg     <= {slave_address, rw}; // Cargar nueva dirección
                                bit_cnt    <= 3'd7;
                                sda_oe_reg <= 1'b1; // Mantenemos control para generar START
                            end 
                            
                            else begin
                                state      <= ST_RD;
                                bit_cnt    <= 3'd7;
                                sda_oe_reg <= 1'b0; 
                            end
                            
                        end
                    end
                end
///////////////////PENDIENTE DE REVISAR////////////////////
                ST_NACK_ERROR: begin
                    if (phase_tick) begin
                        if (phase == 2'b00) begin 
                            ack_error <= 1'b1;
                            //sda_oe_reg <= 1'b0;
                        end

                        if (phase == 2'b11) begin
                                state <= ST_STOP;
                        end
                    end
                end
                //////////////////PENDIENTE DE REVISAR////////////////////
                ST_STOP: begin
                    if (phase_tick) begin
                        sda_oe_reg <= 1'b1;
                        if (phase == 2'b00) sda_oe_reg <= 1'b1;
                        
                        if (phase == 2'b11) begin
                            busy <= 1'b0;
                            done <= 1'b1;
                            state <= ST_IDLE;
                        end
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end

  
    end
    
    /*
    Diagrama de tiempos I2C durante una transmisión completa.
    ESTADO:    [ IDLE ] [     START    ]  [    BIT(1)    ] [...] [      RD    ]  [...]  [    BIT(0)     ]    [      STOP    ]
    FASE:       (fijo)   00  01  10  11    00  01  10  11        00  01  10  11        00  01  10  11     00  01  10  11

    SCL:   ... 11111111 1111111111110000  0000111111110000  ...  0000111111110000 ...  0000111111110000   0000111111111111
                        |   |   |   |  |   |   |   |             |   |   |   |         |   |   |   |      |   |   |   |
    SDA:   ... 11111111 1111111100000000  1111111111111111  ...  zzzzzzzzzzzzzzzz  ... 0000000000000000   0000000011111111
                               ^          ^       ^              ^       ^             ^       ^          ^       ^
    Eventos:                 START      Setup   Hold          Setup    Hold         Setup     STOP        Setup     STOP
    */
    always @(posedge clk_system or posedge reset) begin
        if (reset) begin
            sda_out_reg <= 1'b1; // Línea SDA en alto (idle)
            scl_reg <= 1'b1; // Línea SCL en alto (idle) 
        end
        else begin
            // Lógica para controlar SCL según el estado y la fase; genera condiciones START y STOP
            case (state)
                ST_START: begin
                    case (phase)
                        2'b00: begin
                            sda_out_reg <= 1'b1; 
                            scl_reg <= 1'b1; 
                        end
                        2'b01: begin
                            sda_out_reg <= 1'b1; 
                            scl_reg <= 1'b1; 
                        end
                        2'b10: begin
                            sda_out_reg <= 1'b0; 
                            scl_reg <= 1'b1; 
                        end
                        2'b11: begin
                            sda_out_reg <= 1'b0; 
                            scl_reg <= 1'b0; 
                        end
                    endcase
                end

                ST_STOP: begin
                    case (phase)
                        2'b00: begin
                            sda_out_reg <= 1'b0; 
                            scl_reg <= 1'b0; 
                        end
                        2'b01: begin
                            sda_out_reg <= 1'b0; 
                            scl_reg <= 1'b1; 
                        end
                        2'b10: begin
                            sda_out_reg <= 1'b1; 
                            scl_reg <= 1'b1; 
                        end
                        2'b11: begin
                            sda_out_reg <= 1'b1; 
                            scl_reg <= 1'b1; 
                        end
                    endcase
                end

                ST_IDLE: begin
                    sda_out_reg <= 1'b1; // Mantener SDA en alto en IDLE
                    scl_reg <= 1'b1; // Mantener SCL en alto en IDLE
                end

                ST_MASTER_ACK: begin
                    case (phase)
                        2'b00: begin
                            sda_out_reg <= start|stop; 
                            scl_reg <= 1'b0; 
                        end
                        2'b01: scl_reg <= 1'b1;
                        2'b10: scl_reg <= 1'b1;
                        2'b11: scl_reg <= 1'b0;
                    endcase
                end

                ST_NACK_ERROR: begin
                sda_oe_reg <= 1'b1;
                scl_reg    <= 1'b0; // Mantener SCL bajo
                // sda_out_reg no importa tanto, pero idealmente 0 para preparar el STOP
            end

                default: begin
                    case (phase)
                        2'b00: begin
                            if (sda_oe_reg)
                                sda_out_reg <= dr_reg[bit_cnt];  // setup del bit
                            scl_reg <= 1'b0; 
                        end
                        2'b01: scl_reg <= 1'b1; 
                        2'b10: scl_reg <= 1'b1; 
                        2'b11: scl_reg <= 1'b0; 
                    endcase
                end
            endcase
        end
    end

endmodule
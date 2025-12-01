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

    // Entradas de control
    input  wire        start,        // petición de START / RESTART
    input  wire        stop,         // petición de STOP
    input  wire        rw,           // 0 = write, 1 = read
    input  wire [7:0]  data_in,      // byte a enviar
    input  wire [6:0]  slave_address,// dirección del esclavo (SLA)
    input wire         wait_flag,

    // Salidas de estado
    output reg         busy,
    output reg         done,
    output reg         ack_error,
    output reg         op_done,
    output reg [7:0]   data_out
    );

    // Registros internos
    reg [2:0] bit_cnt;
    reg [7:0] dr_reg;
    reg  sda_out_reg;
    reg  sda_oe_reg;
    wire sda_in;
    reg  scl_reg;

    // Buffer Tri-estado
    assign sda    = sda_oe_reg ? sda_out_reg : 1'bz;
    assign sda_in = sda;
    assign scl    = scl_reg;


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
    wire [1:0]  phase;        
    wire phase_tick;
    
    i2c_phase_generator #(.FRECUENCIA(F_SCL)) phase_gen (
        .reset    (reset),
        .clk_input(clk_system),
        .enable   (busy),
        .tick     (phase_tick),
        .phase    (phase),
        .tick_end (phase_tick_end)
    );

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
        ST_STOP       = 4'd9,
        ST_WAIT       = 4'd10;

    reg [3:0] state;
    reg [3:0] next_state;
    reg [3:0] prev_state;
    
    // Banderas de Transición
    reg       is_restart; 

    // -------------------------------------------------------------------------
    // BLOQUE 1: FSM PRINCIPAL
    // -------------------------------------------------------------------------
    always @(posedge clk_system or posedge reset) begin

        if (reset) begin
            busy        <= 1'b0;
            done        <= 1'b0;
            ack_error   <= 1'b0;
            data_out    <= 0;
            bit_cnt     <= 3'd0;
            sda_oe_reg  <= 1'b0;
            state       <= ST_IDLE;
            dr_reg      <= 0;
            is_restart  <= 1'b0;
            prev_state  <= ST_IDLE;
            next_state  <= ST_IDLE;   // ← AÑADE ESTA LÍNEA
            op_done     <= 1'b0;
            


        end
        else begin
            // 1. LÓGICA DE ESTADOS
            case (state)

                ST_IDLE: begin
                    busy      <= 1'b0;
                    done      <= 1'b0;
                    ack_error <= 1'b0;   
                    data_out  <= 0;
                    bit_cnt   <= 3'd0;
                    sda_oe_reg <= 1'b0;
                    op_done   <= 1'b0;

                    is_restart <= 1'b0;
                    
                    if (start) begin
                        busy       <= 1'b1;
                        done       <= 1'b0;
                        bit_cnt    <= 3'd7;
                        dr_reg     <= {slave_address, rw}; 
                        state      <= ST_START;
                    end
                end

                ST_START: begin
                    //Control de inicio
                    sda_oe_reg <= 1'b1;

                    //Control de salida
                    if (phase == 2'b11 && phase_tick_end) begin 
                        next_state <= ST_ADDRRW;
                        state <= ST_WAIT;
                        is_restart <= 1'b0;
                        op_done <= 1'b1;
                    end
                end

                ST_ADDRRW: begin
                    //Control de inicio
                    sda_oe_reg <= 1'b1; 

                    //Control de salida
                    if (phase == 2'b11 && phase_tick_end) begin
                        if (bit_cnt == 0) begin   
                            state <= ST_SLV_ACK1;
                        end else 
                            bit_cnt <= bit_cnt - 1;
                    end
                end

                ST_SLV_ACK1: begin
                    //Control de inicio
                    sda_oe_reg <= 1'b0; 
                    if (phase == 2'b00 && phase_tick) ack_error <= 1'b0;
                        
                    //Lectura de ACK justo a la mitad de scl positivo
                    if (phase == 2'b10 && phase_tick) ack_error <= sda_in; 

                    //Control de salida
                    if (phase == 2'b11 && phase_tick_end) begin  
                        if (ack_error == 1'b0) begin 
                            if (rw == 1'b0) begin
                                dr_reg     <= data_in;
                                bit_cnt    <= 3'd7;
                                next_state      <= ST_WR; 
                            end else begin
                                bit_cnt    <= 3'd7;
                                next_state      <= ST_RD; 
                            end
                        end else begin 

                            ack_error  <= 1'b1;
                            next_state <= ST_STOP;
                        end
                        state <= ST_WAIT;
                        op_done <= 1'b1;
                    end
                end

                ST_WR: begin
                    sda_oe_reg <= 1'b1;
                        
                    if (phase == 2'b11 && phase_tick_end) begin
                        if (bit_cnt == 0) begin   
                            state <= ST_SLV_ACK2;
                        end else 
                            bit_cnt <= bit_cnt - 1;
                    end
                end

                ST_SLV_ACK2: begin
                    //Control de inicio
                    sda_oe_reg <= 1'b0;

                    if (phase == 2'b10 && phase_tick) ack_error <= sda_in;   
                    
                    //Control de salida
                    if (phase == 2'b11 && phase_tick_end) begin
                        state <= ST_WAIT;
                        op_done <= 1'b1;
                        prev_state <= ST_SLV_ACK2;
                    end
                end

                ST_RD: begin
                    //Control de inicio
                    sda_oe_reg <= 1'b0; 

                    if (phase == 2'b10 && phase_tick) dr_reg[bit_cnt] <= sda_in; 

                    //Control de salida
                    if (phase == 2'b11 && phase_tick_end) begin
                        if (bit_cnt == 0) begin
                            data_out <= dr_reg; 
                            next_state    <= ST_MASTER_ACK;
                            state <= ST_WAIT;
                            op_done <= 1'b1;
                        end else 
                            bit_cnt <= bit_cnt - 1;

                    end   
                end

                ST_MASTER_ACK: begin
                    //Control de inicio
                    sda_oe_reg <= 1'b1; 
        
                    //Control de salida
                    if (phase == 2'b11 && phase_tick_end) begin
                        state <= ST_WAIT;
                        op_done <= 1'b1;
                        prev_state <=  ST_MASTER_ACK;
                    end
                end

                ST_NACK_ERROR: begin
                    //Control de inicio
                    sda_oe_reg <= 1'b1;
                    ack_error  <= 1'b1;

                    //Control de salida
                    if (phase == 2'b11 && phase_tick_end) begin
                        next_state <= ST_STOP;  // después del error vamos a STOP
                        state      <= ST_WAIT;  // pero primero pasamos por WAIT bloqueante
                        op_done    <= 1'b1;     // avisamos al CPU que hubo evento (con error)
                    end
                end
                ST_STOP: begin
                    //Control de inicio
                    sda_oe_reg <= 1'b1;

                    //Control de salida
                    if (phase == 2'b11 && phase_tick_end) begin
                        busy  <= 1'b0;
                        done  <= 1'b1;
                        state <= ST_IDLE;
                    end
                end
                ////////////////CAMBIO REALIZADO, PRUEBA////////////////
                ST_WAIT: begin
                    
                    if (wait_flag) op_done <= 1'b0;
                    if (phase == 2'b11 && phase_tick_end && op_done == 1'b0) begin
                        

                        if (prev_state == ST_SLV_ACK2) begin
                            if (ack_error == 1'b0) begin 
                                if (stop) begin
                                    state <= ST_STOP;
                                end else if (start) begin
                                    bit_cnt    <= 3'd7;
                                    dr_reg     <= {slave_address, rw}; 
                                    is_restart <= 1'b1;
                                    state      <= ST_START;
                                end else begin
                                    dr_reg  <= data_in;
                                    bit_cnt <= 3'd7;
                                    state   <= ST_WR;
                                end
                            end else begin 
                                ack_error <= 1'b1;
                                state     <= ST_STOP;
                            end

                        end else if (prev_state == ST_MASTER_ACK) begin
                            if (stop) begin
                                state <= ST_STOP;
                            end else if (start) begin
                                dr_reg     <= {slave_address, rw}; 
                                bit_cnt    <= 3'd7;
                                is_restart <= 1'b1;
                                state      <= ST_START;
                            end else begin
                                bit_cnt <= 3'd7;
                                state   <= ST_RD;
                            end

                        end else begin
                            // Para los que usaron next_state (START, ACK1, RD, NACK_ERROR)
                            state <= next_state;
                        end

                        // aquí sí, al final del “evento” de WAIT:
                        prev_state <= ST_IDLE;
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

    // -------------------------------------------------------------------------
    // BLOQUE 2: GENERADOR DE SEÑALES FÍSICAS  
    // -------------------------------------------------------------------------
    always @(posedge clk_system or posedge reset) begin
        if (reset) begin
            sda_out_reg <= 1'b1; 
            scl_reg     <= 1'b1; 
        end
        else begin
            case (state)
                ST_START: begin
                    case (phase)
                        2'b00: begin 
                            scl_reg <= (is_restart) ? 1'b0 : 1'b1; 
                            sda_out_reg <= 1'b1;  
                            end
                        2'b01: begin sda_out_reg <= 1'b1; scl_reg <= 1'b1; end
                        2'b10: begin sda_out_reg <= 1'b0; scl_reg <= 1'b1; end 
                        2'b11: begin sda_out_reg <= 1'b0; scl_reg <= 1'b0; end
                    endcase
                end

                ST_STOP: begin
                    case (phase)
                        2'b00: begin sda_out_reg <= 1'b0; scl_reg <= 1'b0; end 
                        2'b01: begin sda_out_reg <= 1'b0; scl_reg <= 1'b1; end 
                        2'b10: begin sda_out_reg <= 1'b1; scl_reg <= 1'b1; end 
                        2'b11: begin sda_out_reg <= 1'b1; scl_reg <= 1'b1; end
                    endcase
                end

                ST_IDLE: begin
                    sda_out_reg <= 1'b1; scl_reg <= 1'b1; 
                end

                ST_MASTER_ACK: begin
                    case (phase)
                        2'b00: begin sda_out_reg <= start|stop; scl_reg <= 1'b0; end
                        2'b01: scl_reg <= 1'b1;
                        2'b10: scl_reg <= 1'b1;
                        2'b11: scl_reg <= 1'b0;
                    endcase
                end

                ST_NACK_ERROR: begin
                    scl_reg    <= 1'b0; 
                end

                ST_WAIT: begin
                    sda_out_reg <= 1'b0;
                    scl_reg <= 1'b0;                    
                end

                default: begin
                    case (phase)
                        2'b00: begin
                            if (sda_oe_reg)
                                sda_out_reg <= dr_reg[bit_cnt]; 
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
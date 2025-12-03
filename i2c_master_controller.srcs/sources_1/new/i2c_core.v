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
    input  wire        reset,       // señal de reset asíncrono
    input  wire        clk_system,  // reloj del sistema (100MHz basys3)

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
    output reg         busy,         // indica que el core está ocupado
    output reg         done,         // indica que se llegó al estado STOP o esta en IDLE
    output reg         ack_error,    // indica error de ACK (se recibió NACK)
    output reg         op_done,      // indica que la operación terminó
    output reg [7:0]   data_out      // dato recibido
    );

    //-------- Registros internos --------
    // Registros de control
    reg [2:0]   bit_cnt;               // contador de bits
    reg [7:0]   dr_reg;                // registro de datos

    // Registro de control de buss SDA y SCL
    reg         sda_out_reg;           // registro de salida SDA
    reg         sda_oe_reg;            // habilitación de salida SDA
    reg         scl_reg;               // registro de salida SCL

    // FSM estados
    reg [3:0]   state;                 // estado actual
    reg [3:0]   next_state;            // próximo estado
    reg [3:0]   prev_state;            // estado previo
    reg         is_restart;            // indica si la operación es un RESTART

    //-------- Señales internas --------
    wire        sda_in;                // entrada SDA
    wire [1:0]  phase;                 // fase del ciclo I2C  
    wire        phase_tick;            // pulso que indica cambio de fase
    wire        phase_tick_end;        // pulso que indica fin de fase

    // Buffer Tri-estado
    // Si sda_oe_reg es 1, el core controla SDA (salida)
    assign sda    = sda_oe_reg ? sda_out_reg : 1'bz; 
    assign sda_in = sda;        // lectura de SDA
    assign scl    = scl_reg;    // salida SCL


    /*------------------------------ Para phase tick ------------------------------
    Reloj (100MHz):  _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_
    Phase (Lento):   000000000000000111111111111111111222222222222222222
    Phase_Tick:      _______________Λ_________________Λ__________________
                                    ^                 ^
                                    |                |
                            "¡Cambié a 01!"      "¡Cambié a 10!"

    ------------------------------Para phase tick end------------------------------
    Reloj (100MHz):  _-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_
    Phase (Lento):   0000000000000111111111111111111222222222222222222
    Phase_Tick_End: _____________Λ_________________Λ__________________
                                ^                 ^
                                |                |
                        "Terminó fase 00"    "Terminó fase 01"                  */
    
    // ---------------- Instancia del generador de fases ----------------
    i2c_phase_generator #(.FRECUENCIA(F_SCL)) phase_gen (
        .reset    (reset),
        .clk_input(clk_system),
        .enable   (busy),
        .tick     (phase_tick),
        .phase    (phase),
        .tick_end (phase_tick_end)
    );

    // ---------------- Definición de estados de la FSM ----------------
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

    // -------------------------------------------------------------------------
    // BLOQUE 1: FSM PRINCIPAL
    // -------------------------------------------------------------------------
    always @(posedge clk_system or posedge reset) begin

        if (reset) begin
            // Reset de todos los registros y salidas
            //Salidas
            busy        <= 1'b0;
            done        <= 1'b0;
            ack_error   <= 1'b0;
            data_out    <= 0;
            op_done     <= 1'b0;
            //----- Registros internos -----
            //Registros de control
            bit_cnt     <= 3'd0;
            dr_reg      <= 0;
            //Registros de control de buss SDA y SCL
            sda_oe_reg  <= 1'b0;
            //FSM estados            
            is_restart  <= 1'b0;
            state       <= ST_IDLE;
            prev_state  <= ST_IDLE;
            next_state  <= ST_IDLE; 
            

        end
        else begin
            // 1. LÓGICA DE ESTADOS
            case (state)

                ST_IDLE: begin
                    //Salidas
                    busy        <= 1'b0;
                    done        <= 1'b0;
                    ack_error   <= 1'b0;
                    data_out    <= 0;
                    op_done     <= 1'b0;
                    //Registros de control
                    bit_cnt     <= 3'd0;
                    dr_reg      <= 0;
                    //Registros de control de buss SDA y SCL
                    sda_oe_reg  <= 1'b0;
                    //FSM estados            
                    is_restart  <= 1'b0;


                    // Control de salida
                    //Si se recibe start, se inicia la operación cambiando al estado START
                    if (start) begin
                        busy       <= 1'b1;
                        done       <= 1'b0;

                        bit_cnt    <= 3'd7;
                        dr_reg     <= {slave_address, rw}; // carga de dirección y bit R/W
                        
                        state      <= ST_START;
                    end
                end

                ST_START: begin
                    //----- Control de inicio -----
                    // Registro de habilitación de salida SDA
                    sda_oe_reg <= 1'b1; // Se toma control de SDA

                    //----- Control de salida -----
                    // Espera a que termine la fase 11
                    if (phase == 2'b11 && phase_tick_end) begin 
                        // Preparación del siguiente estado
                        //Como este estado requiere esperar despues de enviarse, se usa next_state
                        next_state <= ST_ADDRRW;
                        state <= ST_WAIT;
                        is_restart <= 1'b0;
                        op_done <= 1'b1;
                    end
                end

                ST_ADDRRW: begin
                    //----- Control de inicio -----
                    sda_oe_reg <= 1'b1; // Se toma control de SDA

                    //----- Control de salida -----
                    // Espera a que termine la fase 11
                    if (phase == 2'b11 && phase_tick_end) begin
                        // No cambia de estado hasta enviar todos los bits
                        if (bit_cnt == 0) begin   
                            state <= ST_SLV_ACK1;
                        end else 
                            bit_cnt <= bit_cnt - 1;
                    end
                end

                ST_SLV_ACK1: begin
                    //----- Control de inicio -----
                    sda_oe_reg <= 1'b0; 
                    if (phase == 2'b00 && phase_tick) ack_error <= 1'b0;
                    
                    //Lectura de ACK justo a la mitad de scl positivo
                    if (phase == 2'b10 && phase_tick) ack_error <= sda_in; 

                    //----- Control de salida -----
                    // Espera a que termine la fase 11
                    if (phase == 2'b11 && phase_tick_end) begin  
                        //Si no hubo error de ACK, se prepara el siguiente estado según rw
                        if (ack_error == 1'b0) begin 
                            if (rw == 1'b0) begin
                                //Write
                                dr_reg     <= data_in;
                                bit_cnt    <= 3'd7;
                                next_state      <= ST_WR; 
                            end else begin
                                //Read
                                bit_cnt    <= 3'd7;
                                next_state      <= ST_RD; 
                            end
                        end else begin 
                            //NACK error
                            ack_error  <= 1'b1;
                            next_state <= ST_STOP;
                        end
                        // Este estado tambien requiere esperar, se usa next_state
                        state <= ST_WAIT;
                        op_done <= 1'b1;
                    end
                end

                ST_WR: begin
                    //----- Control de inicio -----
                    sda_oe_reg <= 1'b1;
                    
                    //----- Control de salida -----
                    // Espera a que termine la fase 11
                    if (phase == 2'b11 && phase_tick_end) begin
                        // No cambia de estado hasta enviar todos los bits
                        if (bit_cnt == 0) begin   
                            state <= ST_SLV_ACK2;
                        end else 
                            bit_cnt <= bit_cnt - 1;
                    end
                end

                ST_SLV_ACK2: begin
                    //----- Control de inicio -----
                    sda_oe_reg <= 1'b0;

                    // Se lee el ACK a mitad de scl positivo
                    if (phase == 2'b10 && phase_tick) ack_error <= sda_in;   
                    
                    //----- Control de salida -----
                    // Espera a que termine la fase 11
                    if (phase == 2'b11 && phase_tick_end) begin
                        // Este estado tambien requiere esperar
                        //Despues de este estado se decide el siguiente estado en WAIT 
                        state <= ST_WAIT;
                        op_done <= 1'b1;
                        prev_state <= ST_SLV_ACK2; //por eso prev_state se guarda aquí
                    end
                end

                ST_RD: begin
                    //----- Control de inicio -----
                    sda_oe_reg <= 1'b0; 
                    
                    // Se lee el bit de datos a mitad de scl positivo
                    if (phase == 2'b10 && phase_tick) dr_reg[bit_cnt] <= sda_in; 

                    //----- Control de salida -----
                    // Espera a que termine la fase 11
                    if (phase == 2'b11 && phase_tick_end) begin
                        // No cambia de estado hasta recibir todos los bits
                        if (bit_cnt == 0) begin
                            // Este estado tambien requiere esperar
                            data_out <= dr_reg;  // se guarda el dato recibido
                            next_state    <= ST_MASTER_ACK;
                            state <= ST_WAIT;
                            op_done <= 1'b1;
                        end else 
                            bit_cnt <= bit_cnt - 1;
                    end   
                end

                ST_MASTER_ACK: begin
                    //----- Control de inicio -----
                    sda_oe_reg <= 1'b1; 
        
                    //----- Control de salida -----
                    if (phase == 2'b11 && phase_tick_end) begin
                        // Este estado tambien requiere esperar para decidir la siguiente acción
                        state <= ST_WAIT;
                        op_done <= 1'b1;
                        prev_state <=  ST_MASTER_ACK;
                    end
                end

                ST_NACK_ERROR: begin
                    //----- Control de inicio -----
                    sda_oe_reg <= 1'b1;
                    ack_error  <= 1'b1;

                    //----- Control de salida -----
                    if (phase == 2'b11 && phase_tick_end) begin
                        next_state <= ST_STOP;  // después del error vamos a STOP
                        state      <= ST_WAIT;  // pero primero pasamos por WAIT 
                        op_done    <= 1'b1;     
                    end
                end
                ST_STOP: begin
                    //----- Control de inicio -----
                    sda_oe_reg <= 1'b1;

                    //----- Control de salida -----
                    if (phase == 2'b11 && phase_tick_end) begin
                        busy  <= 1'b0; // Se indica que el core ya no está ocupado
                        done  <= 1'b1; // Se indica que la operación ha terminado
                        state <= ST_IDLE; // Se regresa a IDLE
                    end
                end
                
                ST_WAIT: begin
                    //----- Control de inicio -----
                    if (wait_flag) op_done <= 1'b0; 

                    //----- Control de salida -----
                    // Espera a que termine la fase 11
                    if (phase == 2'b11 && phase_tick_end && op_done == 1'b0) begin
                        // Decisión del siguiente estado según el estado previo
                        if (prev_state == ST_SLV_ACK2) begin
                            // Si no hubo error de ACK, se prepara el siguiente estado
                            if (ack_error == 1'b0) begin 
                                //Si se quiere terminar la comunicación se debio de activar stop
                                if (stop) begin
                                    state <= ST_STOP;
                                        // Si se quiere un RESTART se debio de activar start
                                end else if (start) begin
                                    bit_cnt    <= 3'd7;
                                    dr_reg     <= {slave_address, rw}; 
                                    is_restart <= 1'b1;
                                    state      <= ST_START;
                                        //Si se quiere seguir escribiendo dejamos start y stop en 0
                                end else begin
                                    dr_reg  <= data_in;
                                    bit_cnt <= 3'd7;
                                    state   <= ST_WR;
                                end
                            end else begin 
                                //NACK error
                                ack_error <= 1'b1;
                                state     <= ST_STOP;
                            end

                        end else if (prev_state == ST_MASTER_ACK) begin
                            // Si se quiere terminar la comunicación se debio de activar stop
                            if (stop) begin
                                state <= ST_STOP;
                                // Si se quiere un RESTART se debio de activar start
                            end else if (start) begin
                                dr_reg     <= {slave_address, rw}; 
                                bit_cnt    <= 3'd7;
                                is_restart <= 1'b1;
                                state      <= ST_START;
                                //Si se quiere seguir leyendo dejamos start y stop en 0
                            end else begin
                                bit_cnt <= 3'd7;
                                state   <= ST_RD;
                            end

                        end else begin
                            // Para los que usaron next_state (START, ACK1, RD, NACK_ERROR)
                            state <= next_state;
                        end

                        // Reinicio de prev_state
                        prev_state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase

        end
    end
    

    /* ------------------------------ Diagrama de tiempos I2C durante una transmisión completa ------------------------------
    ESTADO:    [ IDLE ] [     START    ]  [    BIT(1)    ] [...] [      RD    ]  [...]  [    BIT(0)     ]    [      STOP    ]
    FASE:       (fijo)   00  01  10  11    00  01  10  11        00  01  10  11        00  01  10  11     00  01  10  11

    SCL:   ... 11111111 1111111111110000  0000111111110000  ...  0000111111110000 ...  0000111111110000   0000111111111111
                        |   |   |   |  |   |   |   |             |   |   |   |         |   |   |   |      |   |   |   |
    SDA:   ... 11111111 1111111100000000  1111111111111111  ...  zzzzzzzzzzzzzzzz  ... 0000000000000000   0000000011111111
                            ^          ^       ^              ^       ^             ^       ^          ^       ^
    Eventos:                 START      Setup   Hold          Setup    Hold         Setup     STOP        Setup     STOP */


    // -------------------------------------------------------------------------
    // BLOQUE 2: GENERADOR DE SEÑALES FÍSICAS  
    // -------------------------------------------------------------------------
    always @(posedge clk_system or posedge reset) begin
        if (reset) begin
            //En reinicio las señales SDA y SCL están en alto como en IDLE
            sda_out_reg <= 1'b1;
            scl_reg     <= 1'b1; 
        end
        else begin
            case (state)

                // Se genera START  bajando SDA mientras SCL está en alto
                ST_START: begin
                    case (phase)
                        2'b00: begin 
                            // Si es RESTART, SCL ya esta en bajo por lo que no se cambia
                            scl_reg <= (is_restart) ? 1'b0 : 1'b1; 
                            sda_out_reg <= 1'b1;  
                            end
                        2'b01: begin sda_out_reg <= 1'b1; scl_reg <= 1'b1; end
                        2'b10: begin sda_out_reg <= 1'b0; scl_reg <= 1'b1; end 
                        2'b11: begin sda_out_reg <= 1'b0; scl_reg <= 1'b0; end
                    endcase
                end

                // Se genera STOP subiendo SDA mientras SCL está en alto
                ST_STOP: begin
                    case (phase)
                        2'b00: begin sda_out_reg <= 1'b0; scl_reg <= 1'b0; end 
                        2'b01: begin sda_out_reg <= 1'b0; scl_reg <= 1'b1; end 
                        2'b10: begin sda_out_reg <= 1'b1; scl_reg <= 1'b1; end 
                        2'b11: begin sda_out_reg <= 1'b1; scl_reg <= 1'b1; end
                    endcase
                end

                // En IDLE ambas líneas están en alto
                ST_IDLE: begin
                    sda_out_reg <= 1'b1; scl_reg <= 1'b1; 
                end

                // SDA se define segun el siguiente estado despues 
                // de MASTER_ACK segun previas configuraciones
                ST_MASTER_ACK: begin
                    case (phase)
                        2'b00: begin sda_out_reg <= start|stop; scl_reg <= 1'b0; end
                        2'b01: scl_reg <= 1'b1;
                        2'b10: scl_reg <= 1'b1;
                        2'b11: scl_reg <= 1'b0;
                    endcase
                end

                // En caso de error NACK, se mantiene SCL en bajo
                ST_NACK_ERROR: begin
                    scl_reg    <= 1'b0; 
                end

                // En WAIT, se mantiene scl en bajo sin importar SDA
                // Si scl esta en bajo los esclabos no "escuchan" 
                ST_WAIT: begin
                    scl_reg <= 1'b0;                    
                end

                // En los demás estados (ADDRRW, SLV_ACK1, WR, SLV_ACK2, RD)
                // Se genera el reloj perfectamente coordinado con SDA
                default: begin
                    case (phase)
                        2'b00: begin
                            // Si se está enviando un bit, se coloca el valor en SDA
                            // Si se está leyendo, SDA se deja en alta impedancia
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
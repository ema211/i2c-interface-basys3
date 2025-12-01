`timescale 1ns / 1ps

module bh1750_top (
    input  wire clk,    
    input  wire btnC,     

    inout  wire sda,     
    output wire scl,      

    output wire [6:0] Seg,
    output wire [3:0] T
);

    // ---------------------------------------------------
    // Señales hacia/desde el core I2C
    // ---------------------------------------------------
    localparam [6:0] BH1750_ADDR = 7'h23;

    reg        start_core   = 1'b0;
    reg        stop_core    = 1'b0;
    reg        rw_core      = 1'b1;   // 0 = write, 1 = read
    reg [7:0]  data_in_core = 8'h00; 
    reg [6:0]  addr_core    = BH1750_ADDR;
    reg        wait_flag    = 1'b0;

    wire       busy_core;
    wire       done_core;
    wire       ack_error_core;
    wire       op_done_core;
    wire [7:0] data_out_core;

    // Instancia del core I2C
    i2c_core #(.F_SCL(100_000)) i2c_core_i (
        .reset         (btnC),
        .clk_system    (clk),

        .sda           (sda),
        .scl           (scl),

        .start         (start_core),
        .stop          (stop_core),
        .rw            (rw_core),

        .data_in       (data_in_core),
        .slave_address (addr_core),

        .wait_flag     (wait_flag),

        .busy          (busy_core),
        .done          (done_core),
        .ack_error     (ack_error_core),
        .op_done       (op_done_core),
        .data_out      (data_out_core)
    );

    // ---------------------------------------------------
    // FSM de alto nivel
    // ---------------------------------------------------
    reg [3:0]  app_state;
    reg [23:0] wait_counter;     // para espaciar lecturas globales
    reg [7:0]  last_byte;        // último dato leído

    // “subfase” para la lectura (RD y luego MASTER_ACK)
    reg [1:0]  read_phase;       // 0 = esperando fin RD, 1 = esperando fin MASTER_ACK

    localparam [3:0] 
        IDLE      = 4'd0,
        START1    = 4'd1,
        ADDR1     = 4'd2,
        WRITE_REG = 4'd3,
        STOP1     = 4'd4,
        START2    = 4'd5,
        ADDR2     = 4'd6,
        READ      = 4'd7;

    always @(posedge clk or posedge btnC) begin
        if (btnC) begin
            app_state    <= IDLE;
            wait_counter <= 24'd0;
            last_byte    <= 8'h00;

            start_core   <= 1'b0;
            stop_core    <= 1'b0;
            rw_core      <= 1'b1;     // por defecto lectura
            addr_core    <= BH1750_ADDR;
            data_in_core <= 8'h00;
            wait_flag    <= 1'b0;

            read_phase   <= 2'd0;
        end
        else begin

            case (app_state)

                // -------------------------------------------------
                // IDLE: Espera global entre ciclos de medición
                // -------------------------------------------------
                IDLE: begin
                    // Mantén todo en reposo
                    start_core   <= 1'b0;
                    stop_core    <= 1'b0;
                    wait_flag    <= 1'b0;

                    wait_counter <= wait_counter + 1;
                    if (wait_counter == 24'd10_000_000) begin // ~100 ms a 100 MHz
                        wait_counter <= 24'd0;
                        app_state    <= START1;
                    end
                end

                // -------------------------------------------------
                // START1: start + addr (modo escritura)
                // Aquí se dispara ST_START en el core.
                // -------------------------------------------------
                START1: begin
                    // Configuración para: START + SLA+W
                    rw_core      <= 1'b0;             // write
                    addr_core    <= BH1750_ADDR;
                    data_in_core <= 8'h10;            // ya dejamos preparado el comando

                    start_core   <= 1'b1;             // pedimos START
                    stop_core    <= 1'b0;
                    wait_flag    <= 1'b0;

                    if (op_done_core) begin           // core en ST_WAIT después de START
                        if (wait_counter < 24'd10) begin
                            wait_counter <= wait_counter + 1;
                        end else begin
                            wait_counter <= 24'd0;
                            wait_flag    <= 1'b1;     // liberar WAIT -> pasa a ST_ADDRRW
                            app_state    <= ADDR1;    // siguiente macro-estado: "addr"
                        end
                    end else begin
                        wait_counter <= 24'd0;
                    end
                end

                // -------------------------------------------------
                // ADDR1: espera a que termine ADDR + ACK1
                // Aquí ST_ADDRRW + ST_SLV_ACK1 terminan y el core vuelve a WAIT.
                // -------------------------------------------------
                ADDR1: begin
                    // Ya no necesitamos START aquí
                    start_core <= 1'b0;
                    stop_core  <= 1'b0;
                    wait_flag  <= 1'b0;

                    // op_done_core se levantará al final de ST_SLV_ACK1
                    if (op_done_core) begin
                        if (wait_counter < 24'd10) begin
                            wait_counter <= wait_counter + 1;
                        end else begin
                            wait_counter <= 24'd0;
                            wait_flag    <= 1'b1;     // libera WAIT -> el core pasa a ST_WR
                            app_state    <= WRITE_REG;
                        end
                    end else begin
                        wait_counter <= 24'd0;
                    end
                end

                // -------------------------------------------------
                // WRITE_REG: escribir 0x10 y decidir STOP
                // ST_WR + ST_SLV_ACK2 terminan y el core entra a WAIT
                // con prev_state = ST_SLV_ACK2.
                // Aquí decidimos "stop" en ese WAIT.
                // -------------------------------------------------
                WRITE_REG: begin
                    start_core <= 1'b0;              // no queremos restart aquí
                    wait_flag  <= 1'b0;

                    if (op_done_core) begin          // venimos del ACK del byte (ST_SLV_ACK2 -> WAIT)
                        if (wait_counter < 24'd10) begin
                            wait_counter <= wait_counter + 1;
                        end else begin
                            wait_counter <= 24'd0;

                            // En este WAIT (prev_state = ST_SLV_ACK2):
                            // stop = 1 -> core irá a ST_STOP
                            stop_core <= 1'b1;
                            wait_flag <= 1'b1;        // libera WAIT -> se ejecuta STOP

                            app_state <= STOP1;       // macro-estado para esperar el STOP completo
                        end
                    end else begin
                        wait_counter <= 24'd0;
                    end
                end

                // -------------------------------------------------
                // STOP1: esperar a que termine el STOP
                // Aquí ya no se usa op_done_core, se usa done_core.
                // -------------------------------------------------
                STOP1: begin
                    // Mantenemos stop en 1 mientras termina STOP
                    start_core <= 1'b0;
                    // stop_core  <= 1'b1;  // opcional mantenerlo 1, no hace daño
                    wait_flag  <= 1'b0;

                    if (done_core) begin             // el core terminó ST_STOP -> vuelve a IDLE interno
                        stop_core  <= 1'b0;          // listo para siguiente transacción
                        app_state  <= START2;        // seguimos con: start-addr-leer...
                        wait_counter <= 24'd0;
                    end
                end

                // -------------------------------------------------
                // START2: start + addr (modo lectura)
                // Igual que START1 pero con rw = 1.
                // -------------------------------------------------
                START2: begin
                    rw_core      <= 1'b1;           // read
                    addr_core    <= BH1750_ADDR;
                    start_core   <= 1'b1;           // nuevo START
                    stop_core    <= 1'b0;
                    wait_flag    <= 1'b0;

                    read_phase   <= 2'd0;           // vamos a empezar lectura de byte 0

                    if (op_done_core) begin         // WAIT después de ST_START
                        if (wait_counter < 24'd10) begin
                            wait_counter <= wait_counter + 1;
                        end else begin
                            wait_counter <= 24'd0;
                            wait_flag    <= 1'b1;   // pasar a ST_ADDRRW
                            app_state    <= ADDR2;  // siguiente: addr (lectura)
                        end
                    end else begin
                        wait_counter <= 24'd0;
                    end
                end

                // -------------------------------------------------
                // ADDR2: esperar fin de ADDR + ACK1 en lectura
                // -------------------------------------------------
                ADDR2: begin
                    start_core <= 1'b0;
                    stop_core  <= 1'b0;
                    wait_flag  <= 1'b0;

                    if (op_done_core) begin         // WAIT tras ST_SLV_ACK1 (modo lectura)
                        if (wait_counter < 24'd10) begin
                            wait_counter <= wait_counter + 1;
                        end else begin
                            wait_counter <= 24'd0;
                            wait_flag    <= 1'b1;   // libera WAIT -> core entra a ST_RD
                            app_state    <= READ;   // macro-estado de lectura
                        end
                    end else begin
                        wait_counter <= 24'd0;
                    end
                end

                // -------------------------------------------------
                // READ: leer datos y luego pedir STOP
                //
                // En lectura hay dos op_done por byte:
                //  - op_done después de ST_RD      (dato listo en data_out)
                //  - op_done después de MASTER_ACK (decidimos STOP o más lecturas)
                //
                // Aquí hacemos:
                //   1) primera vez op_done -> RD completo -> guardamos dato -> handshake
                //   2) segunda vez op_done -> MASTER_ACK -> pedimos STOP -> handshake -> volvemos a IDLE
                //
                // Para "leer-leer-stop" se extendería este patrón a 2 bytes usando read_phase.
                // -------------------------------------------------
                READ: begin
                    start_core <= 1'b0;
                    wait_flag  <= 1'b0;

                    if (op_done_core) begin
                        if (wait_counter < 24'd10) begin
                            wait_counter <= wait_counter + 1;
                        end else begin
                            wait_counter <= 24'd0;

                            case (read_phase)
                                2'd0: begin
                                    // Primera vez que vemos op_done en READ:
                                    // corresponde a fin de ST_RD (byte leído).
                                    last_byte <= data_out_core;  // guardamos el byte leído
                                    // Aquí NO ponemos stop todavía, solo handshake
                                    stop_core <= 1'b0;
                                    wait_flag <= 1'b1;           // pasar a MASTER_ACK
                                    read_phase <= 2'd1;
                                end

                                2'd1: begin
                                    // Segunda vez que vemos op_done:
                                    // corresponde a fin de MASTER_ACK.
                                    // Aquí ya pedimos STOP.
                                    stop_core  <= 1'b1;          // en WAIT con prev_state=MASTER_ACK -> ST_STOP
                                    wait_flag  <= 1'b1;          // liberamos WAIT
                                    read_phase <= 2'd0;
                                    app_state  <= IDLE;          // terminamos: start-addr-leer-stop
                                end

                                default: begin
                                    read_phase <= 2'd0;
                                    app_state  <= IDLE;
                                end
                            endcase
                        end
                    end else begin
                        wait_counter <= 24'd0;
                    end
                end

                default: app_state <= IDLE;
            endcase
        end
    end

    // ---------------------------------------------------
    // Display 7 segmentos
    // Muestra el byte leído:
    //   - D0 = nibble bajo
    //   - D1 = nibble alto
    //   - D2, D3 = 0
    // ---------------------------------------------------
    Displays7SegIndividual display_i (
        .D0  (last_byte[3:0]),
        .D1  (last_byte[7:4]),
        .D2  (4'h0),
        .D3  (4'h0),
        .rst (btnC),
        .clk (clk),
        .Seg (Seg),
        .T   (T)
    );

endmodule

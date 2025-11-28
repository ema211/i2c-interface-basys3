`timescale 1ns / 1ps

module i2c_core_tb;

    reg clk = 0;
    reg reset = 1;
    
    // Entradas del Core
    reg start = 0;
    reg stop = 0;
    reg rw = 0;       // 0=Write, 1=Read
    reg [7:0] data_in = 8'hCB; // Dato a escribir (11001011)
    reg [7:0] slave_address = 8'h55; // Dirección del esclavo (1010101)

    // Salidas del Core
    wire scl;
    wire busy;
    wire done;
    wire ack_error;
    wire [7:0] data_out;

    // Bus SDA
    tri1 sda;
    
    // Control del Testbench (Esclavo Simulado)
    reg ack_force = 1;      // Para mandar ACKs (0=ACK, 1=Nada)
    reg [7:0] data_to_send = 8'h33; // Dato que el "sensor" va a mandar (00110011)
    reg sda_drive_data = 1; // Para mandar bits de datos (0=Low, 1=HighZ)

    // Lógica del Bus:
    // El Testbench puede jalar a tierra por dos razones:
    // 1. Para mandar un ACK (ack_force=0)
    // 2. Para mandar un bit '0' de datos (sda_drive_data=0)
    assign sda = ((ack_force == 0) || (sda_drive_data == 0)) ? 1'b0 : 1'bz;

    // Instancia del Core
    i2c_core #(.F_SCL(100_000)) uut (
        .reset(reset), 
        .clk_system(clk), 
        .sda(sda), 
        .scl(scl), 
        .start(start), 
        .stop(stop), 
        .rw(rw),
        .data_in(data_in), 
        .slave_address(slave_address),
        .busy(busy),
        .done(done),
        .ack_error(ack_error),
        .data_out(data_out)
    );

    always #5 clk = ~clk; 

    // --- SECUENCIA MAESTRA ---
    initial begin
        // 1. INICIALIZAR
        #100; reset = 0; 
        #100;

        // -----------------------------------------------------------
        // FASE 1: ESCRITURA (Address + Register)
        // -----------------------------------------------------------
        start = 1; 
        rw = 0; // Write
        #20; start = 0;

        // A. Dirección (Write)
        repeat(8) @(posedge scl); // Esperar 8 bits
        @(negedge scl); #2500;
        ack_force = 0; // ACK del Esclavo
        @(negedge scl); #2500;
        ack_force = 1; // Soltar    

        // B. Dato (Registro a leer, ej 0xCB)
        repeat(8) @(posedge scl);
        @(negedge scl); #2500;
        ack_force = 0; // ACK del Esclavo
        
        // En lugar de STOP, mandamos START de nuevo.
        start = 1; 
        rw = 1; // ¡CAMBIO A LECTURA!
        
        @(negedge scl); #2500;
        ack_force = 1; // Soltar ACK
        #20; start = 0; // Quitar pulso de start

        // -----------------------------------------------------------
        // FASE 2: LECTURA (Address + Read Byte)
        // -----------------------------------------------------------
        
        // C. Dirección (Read)
        // El core manda la dirección otra vez (0x55) pero con RW=1
        repeat(9) @(posedge scl);
        @(negedge scl); #2500;
        ack_force = 0; // ACK del Esclavo
        @(negedge scl); #2500;
        ack_force = 1; // Soltar

        // D. SIMULAR ENVÍO DE DATOS DEL ESCLAVO (0x33)
        // Aquí el Testbench tiene que escribir en SDA bit a bit
        // Data: 0x33 = 0011 0011
        
        // Bit 7 (0)
        sda_drive_data = 0; // Bajamos línea
        @(negedge scl);     // Esperamos un ciclo completo
        
        // Bit 6 (0)
        sda_drive_data = 0; 
        @(negedge scl);
        
        // Bit 5 (1)
        sda_drive_data = 1; // Soltamos (High)
        @(negedge scl);

        // Bit 4 (1)
        sda_drive_data = 1; 
        @(negedge scl);

        // Bit 3 (0)
        sda_drive_data = 0; 
        @(negedge scl);

        // Bit 2 (0)
        sda_drive_data = 0; 
        @(negedge scl);

        // Bit 1 (1)
        sda_drive_data = 1; 
        @(negedge scl);

        // Bit 0 (1)
        sda_drive_data = 1; 
        @(negedge scl); // Al terminar este ciclo, el Master lee el último bit

        //Comprobacion del dato completo
        if (data_out == 8'h33) $display("LECTURA CORRECTA! Dato: %h", data_out);
        else $display("ERROR DE LECTURA. Esperaba 33, llego %h", data_out);

        // -----------------------------------------------------------
        // FASE 3: MASTER ACK Y STOP
        // -----------------------------------------------------------

        // El Master debe mandar NACK (1).
        // Preparamos la orden de STOP para que el Core sepa qué hacer.
        stop = 1;

        // Esperamos el ciclo de ACK del Master
        @(posedge scl);
        if (sda === 1'b1) $display("¡EXITO! Master mando NACK correctamente.");
        else              $display("ERROR: Master debio mandar NACK (1).");
        
        @(negedge scl); // Termina ciclo ACK
        #20; stop = 0;

        // Fin de la historia
        wait(done == 1);
        #2000;
                  

        $stop;
    end

endmodule
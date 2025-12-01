`timescale 1ns / 1ps

module i2c_core_tb;

    reg clk   = 0;
    reg reset = 1;
    
    // Entradas del Core
    reg start = 0;
    reg stop  = 0;
    reg rw    = 0;              // 0=Write, 1=Read
    reg [7:0] data_in = 8'hCB;  // Dato a escribir (11001011)
    reg [6:0] slave_address = 0; // Dirección del esclavo 
    reg       wait_flag = 0;    // ← ENTRADA al core, la maneja el TB

    // Salidas del Core
    wire scl;
    wire busy;
    wire done;
    wire ack_error;
    wire [7:0] data_out;
    wire op_done;               // ← SALIDA del core, por eso es wire

    // Bus SDA (open-drain con pull-up débil)
    tri1 sda;
    
    // Control del Testbench (Esclavo Simulado)
    reg ack_force     = 1;      // 0=ACK, 1=No conduce
    reg [7:0] data_to_send = 8'h33; // Dato que el "sensor" va a mandar
    reg sda_drive_data = 1;     // 0=Forzar 0, 1=Z

    // Lógica del Bus:
    assign sda = ((ack_force == 0) || (sda_drive_data == 0)) ? 1'b0 : 1'bz;

    // Instancia del Core
    i2c_core #(.F_SCL(100_000)) uut (
        .reset         (reset), 
        .clk_system    (clk), 
        .sda           (sda), 
        .scl           (scl), 
        .start         (start), 
        .stop          (stop), 
        .rw            (rw),
        .data_in       (data_in), 
        .slave_address (slave_address),
        .wait_flag     (wait_flag),   // ← ahora sí conectado
        .busy          (busy),
        .done          (done),
        .ack_error     (ack_error),
        .op_done       (op_done),
        .data_out      (data_out)
    );

    // Reloj 100 MHz
    always #5 clk = ~clk; 

    // --- SECUENCIA MAESTRA ---
    initial begin
        // INICIALIZAR
        #100; 
        reset = 0; 
        #100;

        // -----------------------------------------------------------
        // FASE 1: ESCRITURA (Address + Register)
        // -----------------------------------------------------------

        ////////A. Generar START y reinicio de bandera////////
        start = 1; 
        rw    = 0; // Write
        slave_address = 7'h23; // Dirección del esclavo BH1750

        // Esperar a que el core marque op_done (operación completada)
        wait(op_done == 1);
        #100;

        //Tiempo donde el CPU configura nuevos registros y al mismo tie
        slave_address = 7'h55; // Cambiamos la dirección del esclavo

        // CPU ya leyó op_done y lo limpia con wait_flag
        wait_flag = 1'b1;
        #20;
        wait_flag = 1'b0;        

        //////// B. Dirección (Write)////////
        //1. Mandar direccion al bus
        repeat(8) @(posedge scl);         // Esperar 8 flancos de SCL (SLA+W)

        //2. Esclavo escribe ack
        @(negedge scl); #2500;
        ack_force = 0;                    // ACK del Esclavo
        @(negedge scl); #2500;
        ack_force = 1;                    // Soltar 
        #200;

        //3. Esperar a que el core marque op_done (operación completada)
        wait(op_done == 1);
        #100;

        //4. Tiempo donde el CPU configura nuevos registros
        

        // 5. Simular que la CPU ya leyó op_done y lo limpia con wait_flag
        wait_flag = 1'b1;
        #20;
        wait_flag = 1'b0;

        //////// C. Dato (Registro a escribir, ej 0xCB)////////
        //1. Mandar direccion al bus
        repeat(8) @(posedge scl);

        //2. Esclavo escribe ack
        @(negedge scl); #2500;
        ack_force = 0; // ACK del Esclavo
        @(negedge scl); #2500;
        ack_force = 1; // Soltar ACK
        #200;
        
        //3. Esperar a que el core marque op_done (operación completada)
        wait(op_done == 1);
        #100;

        //4. Tiempo donde el CPU configura nuevos registros
        // En lugar de STOP, mandamos START de nuevo para lectura

        
        // 5. Simular que la CPU ya leyó op_done y lo limpia con wait_flag
        wait_flag = 1'b1;
        #20;
        wait_flag = 1'b0;
        start = 1; 
        #20000;
        start = 0;

        wait(op_done == 1);
        #100;
        wait_flag = 1'b1;
        #20;
        wait_flag = 1'b0;
        // -----------------------------------------------------------
        // FASE 2: LECTURA (Address + Read Byte)
        // -----------------------------------------------------------
        // D. Dirección (Read)
        //1. Mandar direccion al bus
        repeat(8) @(posedge scl);
        //4. Tiempo donde el CPU configura nuevos registros
        rw    = 1; // CAMBIO A LECTUR
        //2. Esclavo escribe ack
        @(negedge scl); #2500;
        ack_force = 0; // ACK del Esclavo
        @(negedge scl); #2500;
        ack_force = 1; // Soltar ACK
        #200;                   // Soltar

        //3. Esperar a que el core marque op_done (operación completada)
        wait(op_done == 1);
        #100;



        // 5. Simular que la CPU ya leyó op_done y lo limpia con wait_flag
        wait_flag = 1'b1;
        #20;
        wait_flag = 1'b0;
        
        //E. SIMULAR ENVÍO DE DATOS DEL ESCLAVO (0x33 = 0011 0011)
        
        // Bit 7 (0)
        sda_drive_data = 0; 
        @(negedge scl);
        
        // Bit 6 (0)
        sda_drive_data = 0; 
        @(negedge scl);
        
        // Bit 5 (1)
        sda_drive_data = 1; 
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

        
        
        //1. Esperar a que el core marque op_done (operación completada)
        wait(op_done == 1);
        #100;

        //2. Tiempo donde el CPU decide a partir del dato recibido
        // El Master debe mandar NACK (1) en el último byte de lectura.
        

        if (data_out == 8'h33) 
            $display("LECTURA CORRECTA! Dato: %h", data_out);
        else 
            $display("ERROR DE LECTURA. Esperaba 33, llego %h", data_out);
            
        // 3. Simular que la CPU ya leyó op_done y lo limpia con wait_flag
        wait_flag = 1'b1;
        #20;
        wait_flag = 1'b0;

        // -----------------------------------------------------------
        // FASE 3: MASTER ACK Y STOP
        // -----------------------------------------------------------
        // Esperamos el ciclo de ACK del Master
        @(posedge scl);
        if (sda === 1'b1) 
            $display("¡EXITO! Master mando NACK correctamente.");
        else              
            $display("ERROR: Master debio mandar NACK (1).");
        
        @(negedge scl); 
        stop = 1;   // Le indicamos al core que después del ACK haga STOP
        #20000; 
        wait(op_done == 1);
        #100;
        wait_flag = 1'b1;
        #20;
        wait_flag = 1'b0;



        #2000;

        $stop;
    end

endmodule

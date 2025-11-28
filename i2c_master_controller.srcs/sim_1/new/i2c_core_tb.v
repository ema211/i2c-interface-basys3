`timescale 1ns / 1ps

module i2c_core_tb;

    reg clk = 0;
    reg reset = 1;
    reg start = 0;
    reg stop = 0;
    reg [7:0] data_in = 8'hCB;
    reg [7:0] slave_address = 8'h55;

    wire scl;
    wire busy;
    wire done;
    wire ack_error; // ¡Arrastra esto a las ondas para ver si hay error!

    tri1 sda;
    reg  ack_force = 1; // 1=Soltar, 0=ACK
    assign sda = (ack_force == 0) ? 1'b0 : 1'bz;

    i2c_core #(.F_SCL(100_000)) uut (
        .reset(reset), 
        .clk_system(clk), 
        .sda(sda), 
        .scl(scl), 
        .start(start), 
        .stop(stop), 
        .rw(1'b0),
        .data_in(data_in), 
        .slave_address(slave_address),
        .busy(busy),
        .done(done),
        .ack_error(ack_error)
    );

    always #5 clk = ~clk; 

    initial begin
        // 1. INICIALIZAR
        #100; reset = 0; 
        #100;

        // 2. MANDAR START
        start = 1; 
        #20; 
        start = 0;

        // --- MAGIA: SINCRONIZACIÓN AUTOMÁTICA ---
        
        // Esperamos 8 flancos positivos de SCL (Los 8 bits de dirección)
        repeat(8) @(posedge scl);
        
        // Esperamos a que SCL baje (Inicio del ciclo ACK)
        
        @(negedge scl); 
        #2500;
        
        // ¡AHORA! Bajamos la línea justo a tiempo
        ack_force = 0; 
        
        // Esperamos a que pase el ciclo de ACK (Subida y bajada de SCL)
        @(negedge scl); 
        #2500;
        ack_force = 1; // Soltamos

        // --- YA PASAMOS EL PRIMER PELIGRO ---

        // Esperamos 8 flancos para el Dato
        repeat(8) @(posedge scl);
        
        // Esperamos bajada para ACK de Dato
        @(negedge scl);
        #2500;
        ack_force = 0; // ACK!
        stop = 1;
        
        @(negedge scl);
        #2500;
        ack_force = 1; // Soltar
        #20;
        stop = 0;



        #2000;
        $stop;
    end

endmodule
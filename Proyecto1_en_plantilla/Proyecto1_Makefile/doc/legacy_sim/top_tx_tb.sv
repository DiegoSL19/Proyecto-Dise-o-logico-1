`timescale 1ns/1ps

module top_tx_tb;

    logic [3:0] datos;
    logic p1;
    logic p2;
    logic p4;
    logic p0;

    logic [2:0] error_pos1;
    logic [2:0] error_pos2;
    logic [6:0] catodo;
    logic [7:0] tx;

    top_tx uut (
        .datos_pi      (datos),
        .p1_pi         (p1),
        .p2_pi         (p2),
        .p4_pi         (p4),
        .p0_pi         (p0),
        .error_pos1_pi (error_pos1),
        .error_pos2_pi (error_pos2),
        .catodo_po (catodo),
        .tx_po         (tx)
       
    );

    // Simulación de los tres 74HC86
    assign p1 = datos[0] ^ datos[1] ^ datos[3];

    assign p2 = datos[0] ^ datos[2] ^ datos[3];

    assign p4 = datos[1] ^ datos[2] ^ datos[3];

    assign p0 =
        p1 ^
        p2 ^
        datos[0] ^
        p4 ^
        datos[1] ^
        datos[2] ^
        datos[3];

    initial begin

        // Dato de prueba
        datos = 4'b1010;

        // Sin errores
        error_pos1 = 3'b000;
        error_pos2 = 3'b000;

        #10;

        // Error posición 3
        error_pos1 = 3'b011;

        #10;

        // Dos errores: posiciones 2 y 6
        error_pos1 = 3'b010;
        error_pos2 = 3'b110;

        #10;

        // Regresar a palabra correcta
        error_pos1 = 3'b000;
        error_pos2 = 3'b000;

        #10;

        $finish;

    end

    initial begin
        $dumpfile("top_tx_tb.vcd");
        $dumpvars(0, top_tx_tb);
    end

endmodule
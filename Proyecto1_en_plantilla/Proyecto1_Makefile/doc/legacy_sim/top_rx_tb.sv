`timescale 1ns/1ps

module top_rx_tb;

    logic [7:0] rx;

    logic [2:0] sindrome;
    logic       paridad_error;

    logic       sin_error;
    logic       corregir;
    logic       error_p0;
    logic       ded;

    logic [6:0] palabra_corregida;
    logic [3:0] datos;


    top_rx uut (
        .rx_pi                  (rx),

        .sindrome_po            (sindrome),
        .paridad_error_po       (paridad_error),

        .sin_error_po           (sin_error),
        .corregir_po            (corregir),
        .error_p0_po            (error_p0),
        .ded_po                 (ded),

        .palabra_corregida_po   (palabra_corregida),
        .datos_po               (datos)
    );


    initial begin

        // ------------------------------------------------
        // CASO 1: palabra correcta
        // Dato original = 1010
        // Código correcto = D2 = 11010010
        // ------------------------------------------------
        rx = 8'hD2;

        #10;


        // ------------------------------------------------
        // CASO 2: un error en posición Hamming 3
        // D2 -> D6
        // El receptor debe detectar síndrome 011
        // y recuperar 1010
        // ------------------------------------------------
        rx = 8'hD6;

        #10;


        // ------------------------------------------------
        // CASO 3: error únicamente en P0
        // D2 XOR 10000000 = 52
        // El síndrome debe permanecer 000
        // pero la paridad global debe fallar
        // ------------------------------------------------
        rx = 8'h52;

        #10;


        // ------------------------------------------------
        // CASO 4: dos errores
        // Posiciones Hamming 2 y 6
        // D2 -> F0
        // Debe activarse DED
        // ------------------------------------------------
        rx = 8'hF0;

        #10;


        // ------------------------------------------------
        // CASO 5: regresar a palabra correcta
        // ------------------------------------------------
        rx = 8'hD2;

        #10;

        $finish;

    end


    initial begin

        $dumpfile("top_rx_tb.vcd");
        $dumpvars(0, top_rx_tb);

    end

endmodule
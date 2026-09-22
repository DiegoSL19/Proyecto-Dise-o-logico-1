module top_tx (

    // Palabra original de cuatro bits
    input logic [3:0] datos_pi,

    // Bits de paridad provenientes de los 74HC86
    input logic p1_pi,
    input logic p2_pi,
    input logic p4_pi,
    input logic p0_pi,

    // Selectores de error
    input logic [2:0] error_pos1_pi,
    input logic [2:0] error_pos2_pi,

    // Palabra enviada al receptor
    output logic [7:0] tx_po,

    // Salidas hacia el display de 7 segmentos
    output logic [6:0] catodo_po
);

    logic [7:0] codigo_hamming;

    // ------------------------------------------------
    // Formación de la palabra SEC-DED
    // ------------------------------------------------

    assign codigo_hamming[0] = p1_pi;
    assign codigo_hamming[1] = p2_pi;
    assign codigo_hamming[2] = datos_pi[0];
    assign codigo_hamming[3] = p4_pi;
    assign codigo_hamming[4] = datos_pi[1];
    assign codigo_hamming[5] = datos_pi[2];
    assign codigo_hamming[6] = datos_pi[3];
    assign codigo_hamming[7] = p0_pi;


    // ------------------------------------------------
    // Generador de errores
    // ------------------------------------------------

    generador_error u_generador_error (
        .codigo_pi       (codigo_hamming),
        .error_pos1_pi   (error_pos1_pi),
        .error_pos2_pi   (error_pos2_pi),
        .codigo_error_po (tx_po)
    );


    // ------------------------------------------------
    // Visualización del dato ORIGINAL
    // ------------------------------------------------

    seven_segment u_display_tx (
        .palabra_pi (datos_pi),
        .catodo_po  (catodo_po)
    );

endmodule
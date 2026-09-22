module receptor_core (
    input  [7:0] codigo_rx_pi,
    output [2:0] sindrome_po,
    output       paridad_error_po,
    output       error_simple_po,
    output       error_doble_po,
    output [7:0] codigo_corregido_po,
    output [3:0] datos_corregidos_po
);

    wire s1;
    wire s2;
    wire s4;

    assign s1 =
        codigo_rx_pi[0] ^
        codigo_rx_pi[2] ^
        codigo_rx_pi[4] ^
        codigo_rx_pi[6];

    assign s2 =
        codigo_rx_pi[1] ^
        codigo_rx_pi[2] ^
        codigo_rx_pi[5] ^
        codigo_rx_pi[6];

    assign s4 =
        codigo_rx_pi[3] ^
        codigo_rx_pi[4] ^
        codigo_rx_pi[5] ^
        codigo_rx_pi[6];

    assign sindrome_po = {s4, s2, s1};


    assign paridad_error_po =
        codigo_rx_pi[0] ^
        codigo_rx_pi[1] ^
        codigo_rx_pi[2] ^
        codigo_rx_pi[3] ^
        codigo_rx_pi[4] ^
        codigo_rx_pi[5] ^
        codigo_rx_pi[6] ^
        codigo_rx_pi[7];


    assign error_simple_po =
        paridad_error_po;

    assign error_doble_po =
        (~paridad_error_po) & (|sindrome_po);


    wire [7:0] mascara_hamming;
    wire [7:0] mascara_correccion;


    assign mascara_hamming =
        (sindrome_po == 3'b001) ? 8'b00000001 :
        (sindrome_po == 3'b010) ? 8'b00000010 :
        (sindrome_po == 3'b011) ? 8'b00000100 :
        (sindrome_po == 3'b100) ? 8'b00001000 :
        (sindrome_po == 3'b101) ? 8'b00010000 :
        (sindrome_po == 3'b110) ? 8'b00100000 :
        (sindrome_po == 3'b111) ? 8'b01000000 :
                                  8'b00000000;


    assign mascara_correccion =
        paridad_error_po ?
            ((sindrome_po == 3'b000)
                ? 8'b10000000
                : mascara_hamming)
            : 8'b00000000;


    assign codigo_corregido_po =
        codigo_rx_pi ^ mascara_correccion;


    assign datos_corregidos_po[0] =
        codigo_corregido_po[2];

    assign datos_corregidos_po[1] =
        codigo_corregido_po[4];

    assign datos_corregidos_po[2] =
        codigo_corregido_po[5];

    assign datos_corregidos_po[3] =
        codigo_corregido_po[6];

endmodule
module sindrome (
    input  logic [6:0] palabra_pi,
    output logic [2:0] sindrome_po
);

    // S1: posiciones 1, 3, 5 y 7
    assign sindrome_po[0] =
        palabra_pi[0] ^
        palabra_pi[2] ^
        palabra_pi[4] ^
        palabra_pi[6];

    // S2: posiciones 2, 3, 6 y 7
    assign sindrome_po[1] =
        palabra_pi[1] ^
        palabra_pi[2] ^
        palabra_pi[5] ^
        palabra_pi[6];

    // S4: posiciones 4, 5, 6 y 7
    assign sindrome_po[2] =
        palabra_pi[3] ^
        palabra_pi[4] ^
        palabra_pi[5] ^
        palabra_pi[6];

endmodule
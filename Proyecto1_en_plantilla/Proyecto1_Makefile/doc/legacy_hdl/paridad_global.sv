module paridad_global (
    input  logic [7:0] palabra_pi,
    output logic       paridad_error_po
);

    assign paridad_error_po =
        palabra_pi[0] ^
        palabra_pi[1] ^
        palabra_pi[2] ^
        palabra_pi[3] ^
        palabra_pi[4] ^
        palabra_pi[5] ^
        palabra_pi[6] ^
        palabra_pi[7];

endmodule
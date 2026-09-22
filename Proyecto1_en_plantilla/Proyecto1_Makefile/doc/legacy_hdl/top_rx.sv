module top_rx (

    // Palabra de 8 bits recibida desde el transmisor
    input logic [7:0] rx_pi,

    // Señales para observación y diagnóstico
    output logic [2:0] sindrome_po,
    output logic       paridad_error_po,

    output logic       sin_error_po,
    output logic       corregir_po,
    output logic       error_p0_po,
    output logic       ded_po,

    // Resultados
    output logic [6:0] palabra_corregida_po,
    output logic [3:0] datos_po
);

    // ------------------------------------------------
    // Verificación de la paridad global de los 8 bits
    // ------------------------------------------------
    paridad_global u_paridad_global (
        .palabra_pi       (rx_pi),
        .paridad_error_po (paridad_error_po)
    );

    // ------------------------------------------------
    // Cálculo del síndrome Hamming de los bits 1-7
    // ------------------------------------------------
    sindrome u_sindrome (
        .palabra_pi  (rx_pi[6:0]),
        .sindrome_po (sindrome_po)
    );

    // ------------------------------------------------
    // Clasificación SEC-DED
    // ------------------------------------------------
    sec_ded u_sec_ded (
        .sindrome_pi      (sindrome_po),
        .paridad_error_pi (paridad_error_po),

        .sin_error_po     (sin_error_po),
        .corregir_po      (corregir_po),
        .error_p0_po      (error_p0_po),
        .ded_po           (ded_po)
    );

    // ------------------------------------------------
    // Corrección del error sencillo
    // ------------------------------------------------
    corrector u_corrector (
        .palabra_pi           (rx_pi[6:0]),
        .sindrome_pi          (sindrome_po),
        .corregir_pi          (corregir_po),

        .palabra_corregida_po (palabra_corregida_po),
        .datos_po             (datos_po)
    );

endmodule
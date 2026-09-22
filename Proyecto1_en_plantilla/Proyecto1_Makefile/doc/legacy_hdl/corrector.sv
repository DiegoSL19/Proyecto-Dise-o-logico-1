module corrector (
    input  logic [6:0] palabra_pi,
    input  logic [2:0] sindrome_pi,
    input  logic       corregir_pi,

    output logic [6:0] palabra_corregida_po,
    output logic [3:0] datos_po
);

    logic [6:0] mascara;

    assign mascara[0] =
        corregir_pi &
        ~sindrome_pi[2] &
        ~sindrome_pi[1] &
         sindrome_pi[0];

    assign mascara[1] =
        corregir_pi &
        ~sindrome_pi[2] &
         sindrome_pi[1] &
        ~sindrome_pi[0];

    assign mascara[2] =
        corregir_pi &
        ~sindrome_pi[2] &
         sindrome_pi[1] &
         sindrome_pi[0];

    assign mascara[3] =
        corregir_pi &
         sindrome_pi[2] &
        ~sindrome_pi[1] &
        ~sindrome_pi[0];

    assign mascara[4] =
        corregir_pi &
         sindrome_pi[2] &
        ~sindrome_pi[1] &
         sindrome_pi[0];

    assign mascara[5] =
        corregir_pi &
         sindrome_pi[2] &
         sindrome_pi[1] &
        ~sindrome_pi[0];

    assign mascara[6] =
        corregir_pi &
         sindrome_pi[2] &
         sindrome_pi[1] &
         sindrome_pi[0];

    assign palabra_corregida_po =
        palabra_pi ^ mascara;

    assign datos_po[0] = palabra_corregida_po[2];
    assign datos_po[1] = palabra_corregida_po[4];
    assign datos_po[2] = palabra_corregida_po[5];
    assign datos_po[3] = palabra_corregida_po[6];

endmodule
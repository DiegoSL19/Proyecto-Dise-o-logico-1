module sec_ded (
    input  logic [2:0] sindrome_pi,
    input  logic       paridad_error_pi,

    output logic       sin_error_po,
    output logic       corregir_po,
    output logic       error_p0_po,
    output logic       ded_po
);

    logic sindrome_cero;
    logic sindrome_no_cero;

    assign sindrome_cero =
        ~sindrome_pi[2] &
        ~sindrome_pi[1] &
        ~sindrome_pi[0];

    assign sindrome_no_cero =
        sindrome_pi[2] |
        sindrome_pi[1] |
        sindrome_pi[0];

    assign sin_error_po =
        sindrome_cero &
        ~paridad_error_pi;

    assign corregir_po =
        sindrome_no_cero &
        paridad_error_pi;

    assign error_p0_po =
        sindrome_cero &
        paridad_error_pi;

    assign ded_po =
        sindrome_no_cero &
        ~paridad_error_pi;

endmodule
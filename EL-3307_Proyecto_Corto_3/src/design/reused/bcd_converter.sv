module bcd_converter #(
    parameter int unsigned N = 10,
    parameter int unsigned M = 12
) (
    input  logic [N-1:0] input_bin,
    output logic [M-1:0] output_bcd
);

    // El archivo se busca en el directorio de trabajo de la simulacion.
    rom_reg #(
        .w(N),
        .b(M),
        .fileName("../design/bcdtable.txt")
    ) ucode (
        .a(input_bin),
        .d(output_bcd)
    );

endmodule

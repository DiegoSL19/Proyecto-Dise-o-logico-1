module rom_reg #(
    parameter int unsigned b = 32,
    parameter int unsigned w = 4,
    parameter fileName = "../design/bcdtable.txt"
) (
    input  logic [w-1:0] a,
    output logic [b-1:0] d
);

    logic [b-1:0] rom [0:(1<<w)-1];

    initial begin
        $readmemh(fileName, rom);
    end

    // Lectura combinacional: la direccion selecciona una entrada de la ROM.
    assign d = rom[a];

endmodule

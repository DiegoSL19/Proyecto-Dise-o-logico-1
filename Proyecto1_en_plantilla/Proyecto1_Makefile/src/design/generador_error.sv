module generador_error (
    input  [7:0] codigo_pi,
    input  [2:0] error1_pi,
    input  [2:0] error2_pi,
    output [7:0] codigo_po
);

    wire [7:0] mascara1;
    wire [7:0] mascara2;

    // Selector de error 1
    assign mascara1 =
        (error1_pi == 3'b001) ? 8'b00000001 :
        (error1_pi == 3'b010) ? 8'b00000010 :
        (error1_pi == 3'b011) ? 8'b00000100 :
        (error1_pi == 3'b100) ? 8'b00001000 :
        (error1_pi == 3'b101) ? 8'b00010000 :
        (error1_pi == 3'b110) ? 8'b00100000 :
        (error1_pi == 3'b111) ? 8'b01000000 :
                               8'b00000000;

    // Selector de error 2
    assign mascara2 =
        (error2_pi == 3'b001) ? 8'b00000001 :
        (error2_pi == 3'b010) ? 8'b00000010 :
        (error2_pi == 3'b011) ? 8'b00000100 :
        (error2_pi == 3'b100) ? 8'b00001000 :
        (error2_pi == 3'b101) ? 8'b00010000 :
        (error2_pi == 3'b110) ? 8'b00100000 :
        (error2_pi == 3'b111) ? 8'b01000000 :
                               8'b00000000;

    // Introducción de errores
    assign codigo_po = codigo_pi ^ mascara1 ^ mascara2;


endmodule
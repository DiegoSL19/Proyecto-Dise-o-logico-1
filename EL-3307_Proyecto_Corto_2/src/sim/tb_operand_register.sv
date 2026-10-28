module tb_operand_register;
    timeunit 1ns;
    timeprecision 1ps;

    logic       clk;
    logic       reset;
    logic       clear;
    logic       load_digit;
    logic [3:0] digit;
    logic [9:0] value;
    int unsigned total_tests;
    int unsigned errors;

    operand_register dut (
        .clk        (clk),
        .reset      (reset),
        .clear      (clear),
        .load_digit (load_digit),
        .digit      (digit),
        .value      (value)
    );

    // Periodo aproximado de 37.036 ns: reloj de prueba de 27 MHz.
    initial begin
        clk = 1'b0;
        forever #18.518ns clk = ~clk;
    end

    task automatic apply_and_check (
        input logic       test_reset,
        input logic       test_clear,
        input logic       test_load,
        input logic [3:0] test_digit,
        input logic [9:0] expected,
        input string      description
    );
        // Aplicar entradas lejos del flanco de captura.
        @(negedge clk);
        reset      = test_reset;
        clear      = test_clear;
        load_digit = test_load;
        digit      = test_digit;

        @(posedge clk);
        #1ns; // Esperar las asignaciones no bloqueantes del DUT.
        total_tests += 1;
        if (value === expected) begin
            $display("PASS: %s | value=%0d", description, value);
        end else begin
            errors += 1;
            $error("FAIL: %s | esperado=%0d, obtenido=%0d",
                   description, expected, value);
        end
    endtask

    initial begin
        reset      = 1'b1;
        clear      = 1'b0;
        load_digit = 1'b0;
        digit      = 4'd0;
        total_tests = 0;
        errors      = 0;

        apply_and_check(1'b1, 1'b0, 1'b0, 4'd0, 10'd0,   "reset");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd1, 10'd1,   "digito 1");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd2, 10'd12,  "digito 2");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd3, 10'd123, "digito 3");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd4, 10'd123, "ignorar cuarto digito 4");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd5, 10'd123, "ignorar quinto digito 5");
        apply_and_check(1'b0, 1'b0, 1'b0, 4'd8, 10'd123, "mantener sin carga");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'hA, 10'd123, "rechazar digito A");
        apply_and_check(1'b0, 1'b1, 1'b0, 4'd0, 10'd0,   "clear");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'hA, 10'd0,   "rechazar A tras clear");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd9, 10'd9,   "digito 9");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd9, 10'd99,  "numero 99");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd9, 10'd999, "numero 999");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd4, 10'd999, "ignorar cuarto digito tras 999");
        apply_and_check(1'b0, 1'b1, 1'b1, 4'd5, 10'd0,   "clear tiene prioridad");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd7, 10'd7,   "carga antes de reset");
        apply_and_check(1'b1, 1'b0, 1'b1, 4'd6, 10'd0,   "reset tiene prioridad");

        // Una A intercalada no debe consumir una posicion.
        apply_and_check(1'b0, 1'b1, 1'b0, 4'd0, 10'd0,   "clear para secuencia 1 A 2 3");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd1, 10'd1,   "secuencia con A: digito 1");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'hA, 10'd1,   "A no consume posicion");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd2, 10'd12,  "secuencia con A: digito 2");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd3, 10'd123, "secuencia 1 A 2 3 termina en 123");

        // Comprobar tambien B, C, D, E, F y ausencia de carga antes del limite.
        apply_and_check(1'b0, 1'b1, 1'b0, 4'd0, 10'd0,   "clear para otros invalidos");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd1, 10'd1,   "primer digito antes de invalidos");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'hB, 10'd1,   "rechazar B");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'hC, 10'd1,   "rechazar C");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'hD, 10'd1,   "rechazar D");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'hE, 10'd1,   "rechazar E");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'hF, 10'd1,   "rechazar F");
        apply_and_check(1'b0, 1'b0, 1'b0, 4'd8, 10'd1,   "sin carga no consume posicion");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd2, 10'd12,  "segundo digito tras invalidos");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd3, 10'd123, "tercer digito tras invalidos");

        // Reset debe permitir otras tres cargas incluso con el contador lleno.
        apply_and_check(1'b1, 1'b0, 1'b1, 4'd6, 10'd0,   "reset con contador lleno");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd9, 10'd9,   "primer digito tras reset");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd9, 10'd99,  "segundo digito tras reset");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd9, 10'd999, "tercer digito tras reset");

        // Los ceros iniciales tambien cuentan como digitos aceptados.
        apply_and_check(1'b0, 1'b1, 1'b0, 4'd0, 10'd0,   "clear para ceros iniciales");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd0, 10'd0,   "primer cero");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd0, 10'd0,   "segundo cero");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd0, 10'd0,   "tercer cero");
        apply_and_check(1'b0, 1'b0, 1'b1, 4'd7, 10'd0,   "ignorar cuarto digito tras 000");

        $display("Total de pruebas: %0d", total_tests);
        $display("Errores: %0d", errors);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");

        $finish;
    end

endmodule

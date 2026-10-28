module tb_subtractor;
    timeunit 1ns;
    timeprecision 1ps;

    logic       clk;
    logic       reset;
    logic       calculate;
    logic [9:0] operand_a;
    logic [9:0] operand_b;
    logic [9:0] magnitude;
    logic       negative;
    logic       result_valid;
    int unsigned total_tests;
    int unsigned errors;

    subtractor dut (
        .clk          (clk),
        .reset        (reset),
        .calculate    (calculate),
        .operand_a    (operand_a),
        .operand_b    (operand_b),
        .magnitude    (magnitude),
        .negative     (negative),
        .result_valid (result_valid)
    );

    // Reloj de prueba de aproximadamente 27 MHz.
    initial begin
        clk = 1'b0;
        forever #18.518ns clk = ~clk;
    end

    task automatic check_cycle (
        input logic       test_reset,
        input logic       test_calculate,
        input logic [9:0] test_a,
        input logic [9:0] test_b,
        input logic [9:0] expected_magnitude,
        input logic       expected_negative,
        input logic       expected_valid,
        input string      description
    );
        @(negedge clk);
        reset     = test_reset;
        calculate = test_calculate;
        operand_a = test_a;
        operand_b = test_b;

        @(posedge clk);
        #1ns; // Esperar la actualizacion de las salidas registradas.
        total_tests += 1;
        if ((magnitude === expected_magnitude) &&
            (negative === expected_negative) &&
            (result_valid === expected_valid)) begin
            $display("PASS: %s | magnitude=%0d negative=%b result_valid=%b",
                     description, magnitude, negative, result_valid);
        end else begin
            errors += 1;
            $error("FAIL: %s | esperado=(%0d,%b,%b) obtenido=(%0d,%b,%b)",
                   description,
                   expected_magnitude, expected_negative, expected_valid,
                   magnitude, negative, result_valid);
        end
    endtask

    task automatic check_calculation (
        input logic [9:0] test_a,
        input logic [9:0] test_b,
        input logic [9:0] expected_magnitude,
        input logic       expected_negative,
        input string      description
    );
        check_cycle(1'b0, 1'b1, test_a, test_b,
                    expected_magnitude, expected_negative, 1'b1,
                    description);
        // Cambiar los operandos sin solicitar otro calculo.
        check_cycle(1'b0, 1'b0, 10'd42, 10'd24,
                    expected_magnitude, expected_negative, 1'b0,
                    {description, " | conservar resultado sin calculate"});
    endtask

    initial begin
        reset       = 1'b1;
        calculate   = 1'b0;
        operand_a   = 10'd0;
        operand_b   = 10'd0;
        total_tests = 0;
        errors      = 0;

        check_cycle(1'b1, 1'b0, 10'd0, 10'd0,
                    10'd0, 1'b0, 1'b0, "reset");

        check_calculation(10'd500, 10'd123, 10'd377, 1'b0, "500 y 123");
        check_calculation(10'd123, 10'd500, 10'd377, 1'b1, "123 y 500");
        check_calculation(10'd999, 10'd0,   10'd999, 1'b0, "999 y 0");
        check_calculation(10'd0,   10'd999, 10'd999, 1'b1, "0 y 999");
        check_calculation(10'd123, 10'd123, 10'd0,   1'b0, "123 y 123");
        check_calculation(10'd1,   10'd0,   10'd1,   1'b0, "1 y 0");
        check_calculation(10'd0,   10'd1,   10'd1,   1'b1, "0 y 1");

        check_cycle(1'b1, 1'b1, 10'd999, 10'd0,
                    10'd0, 1'b0, 1'b0, "reset tiene prioridad sobre calculate");
        check_cycle(1'b0, 1'b0, 10'd123, 10'd500,
                    10'd0, 1'b0, 1'b0, "sin calculo despues del reset");

        $display("Cantidad total de pruebas: %0d", total_tests);
        $display("Cantidad de errores: %0d", errors);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");

        $finish;
    end

endmodule

module tb_calculator_core;
    timeunit 1ns;
    timeprecision 1ps;

    logic       clk;
    logic       reset;
    logic       key_valid;
    logic [3:0] key_code;
    logic [9:0] operand_a;
    logic [9:0] operand_b;
    logic [9:0] magnitude;
    logic       negative;
    logic       result_valid;
    logic       show_result;
    logic       show_operand_b;
    int unsigned total_tests;
    int unsigned errors;

    calculator_core dut (
        .clk          (clk),
        .reset        (reset),
        .key_valid    (key_valid),
        .key_code     (key_code),
        .operand_a    (operand_a),
        .operand_b    (operand_b),
        .magnitude    (magnitude),
        .negative     (negative),
        .result_valid (result_valid),
        .show_result  (show_result),
        .show_operand_b (show_operand_b)
    );

    // Reloj de prueba de aproximadamente 27 MHz.
    initial begin
        clk = 1'b0;
        forever #18.518ns clk = ~clk;
    end

    task automatic press_key(input logic [3:0] code);
        @(negedge clk);
        key_code = code;
        key_valid = 1'b1;
        @(posedge clk);
        #1ns;
        @(negedge clk);
        key_valid = 1'b0;
    endtask

    task automatic report (
        input logic  passed,
        input string description
    );
        total_tests += 1;
        if (passed === 1'b1) begin
            $display("PASS: %s", description);
        end else begin
            errors += 1;
            $error("FAIL: %s | A=%0d B=%0d magnitude=%0d negative=%b result_valid=%b show_result=%b",
                   description, operand_a, operand_b, magnitude,
                   negative, result_valid, show_result);
        end
    endtask

    task automatic check_display (
        input logic expected_operand_b,
        input logic expected_result,
        input string description
    );
        report(({show_operand_b, show_result} ===
                {expected_operand_b, expected_result}), description);
    endtask

    task automatic check_result (
        input logic [9:0] expected_a,
        input logic [9:0] expected_b,
        input logic [9:0] expected_magnitude,
        input logic       expected_negative,
        input string      description
    );
        logic awaiting_result;

        // press_key(B) termina durante CALCULATE, antes de registrar el resultado.
        awaiting_result = (result_valid === 1'b0) &&
                          (show_result === 1'b0);
        check_display(1'b1, 1'b0, {description, " | CALCULATE conserva B"});
        @(posedge clk);
        #1ns; // Esperar las asignaciones no bloqueantes.
        report(awaiting_result &&
               ({operand_a, operand_b, magnitude, negative,
                 result_valid, show_result} ===
                {expected_a, expected_b, expected_magnitude,
                 expected_negative, 1'b1, 1'b1}), description);
        check_display(1'b0, 1'b1, {description, " | seleccion del resultado"});

        @(posedge clk);
        #1ns;
        report(({operand_a, operand_b, magnitude, negative,
                 result_valid, show_result} ===
                {expected_a, expected_b, expected_magnitude,
                 expected_negative, 1'b0, 1'b1}),
               {description, " | pulso de un ciclo y resultado conservado"});
        check_display(1'b0, 1'b1, {description, " | visualizacion estable"});
    endtask

    task automatic clear_for_next_test(input string description);
        press_key(4'hD);
        report(({operand_a, operand_b, show_operand_b, show_result} ===
                {10'd0, 10'd0, 1'b0, 1'b0}),
               {description, " | D limpia en el mismo flanco"});
        @(posedge clk);
        #1ns;
        report(({operand_a, operand_b, result_valid, show_result} ===
                {10'd0, 10'd0, 1'b0, 1'b0}), description);
        check_display(1'b0, 1'b0, {description, " | vuelve a mostrar A"});
    endtask

    initial begin
        reset       = 1'b1;
        key_valid   = 1'b0;
        key_code    = 4'd0;
        total_tests = 0;
        errors      = 0;

        @(posedge clk);
        #1ns;
        report(({operand_a, operand_b, magnitude, negative,
                 result_valid, show_result} ===
                {10'd0, 10'd0, 10'd0, 1'b0, 1'b0, 1'b0}), "reset");
        check_display(1'b0, 1'b0, "reset: control de visualizacion");
        @(negedge clk);
        reset = 1'b0;

        press_key(4'd1);
        press_key(4'd2);
        report(operand_a === 10'd12, "CLEAR INPUT_A: valor previo 12");
        clear_for_next_test("1 -> 2 -> D: operandos y seleccion en cero");

        press_key(4'd4);
        press_key(4'd5);
        press_key(4'hA);
        press_key(4'd1);
        press_key(4'd2);
        report(({operand_a, operand_b, show_operand_b} ===
                {10'd45, 10'd12, 1'b1}), "CLEAR INPUT_B: A=45 y B=12");
        clear_for_next_test("45 -> A -> 12 -> D: operandos y seleccion en cero");

        press_key(4'd1);
        check_display(1'b0, 1'b0, "digito 1 de A");
        press_key(4'd2);
        check_display(1'b0, 1'b0, "digito 2 de A");
        press_key(4'd3);
        check_display(1'b0, 1'b0, "digito 3 de A");
        press_key(4'hA);
        check_display(1'b1, 1'b0, "A selecciona la visualizacion de B");
        press_key(4'd4);
        check_display(1'b1, 1'b0, "digito 4 de B");
        press_key(4'd5);
        check_display(1'b1, 1'b0, "digito 5 de B");
        press_key(4'hB);
        check_result(10'd123, 10'd45, 10'd78, 1'b0, "PRUEBA 1");

        clear_for_next_test("D prepara PRUEBA 2");
        press_key(4'd4);
        check_display(1'b0, 1'b0, "nueva operacion tras D comienza mostrando A");
        press_key(4'd5);
        press_key(4'hA);
        check_display(1'b1, 1'b0, "PRUEBA 2: A selecciona B");
        press_key(4'd1);
        press_key(4'd2);
        press_key(4'd3);
        press_key(4'hB);
        check_result(10'd45, 10'd123, 10'd78, 1'b1, "PRUEBA 2");

        clear_for_next_test("D prepara PRUEBA 3");
        press_key(4'd9);
        check_display(1'b0, 1'b0, "PRUEBA 3 comienza mostrando A");
        press_key(4'd9);
        press_key(4'd9);
        press_key(4'hA);
        check_display(1'b1, 1'b0, "PRUEBA 3: A selecciona B");
        press_key(4'd9);
        press_key(4'd9);
        press_key(4'd9);
        press_key(4'hB);
        check_result(10'd999, 10'd999, 10'd0, 1'b0, "PRUEBA 3");

        $display("Total de pruebas: %0d", total_tests);
        $display("Errores: %0d", errors);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");
        $finish;
    end

endmodule

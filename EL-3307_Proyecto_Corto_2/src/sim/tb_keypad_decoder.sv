module tb_keypad_decoder;
    timeunit 1ns;
    timeprecision 1ps;

    logic [1:0] row_index;
    logic [1:0] column_index;
    logic       key_detected;
    logic [3:0] key_code;
    logic       key_valid;
    int unsigned total_tests;
    int unsigned errors;

    keypad_decoder dut (
        .row_index    (row_index),
        .column_index (column_index),
        .key_detected (key_detected),
        .key_code     (key_code),
        .key_valid    (key_valid)
    );

    task automatic check_key (
        input logic [1:0] test_row,
        input logic [1:0] test_column,
        input logic       detected,
        input logic [3:0] expected_code,
        input string      description
    );
        row_index = test_row;
        column_index = test_column;
        key_detected = detected;
        #1ns; // Permitir que se evalúe la logica combinacional.

        total_tests += 1;
        if ({key_code, key_valid} === {expected_code, detected}) begin
            $display("PASS: %s | key_code=%h key_valid=%b",
                     description, key_code, key_valid);
        end else begin
            errors += 1;
            $error("FAIL: %s | esperado=(%h,%b) obtenido=(%h,%b)",
                   description, expected_code, detected, key_code, key_valid);
        end
    endtask

    initial begin
        total_tests = 0;
        errors = 0;

        check_key(2'd0, 2'd0, 1'b0, 4'h0, "sin deteccion inicial");

        check_key(2'd0, 2'd0, 1'b1, 4'h1, "R1 C1: 1");
        check_key(2'd0, 2'd1, 1'b1, 4'h2, "R1 C2: 2");
        check_key(2'd0, 2'd2, 1'b1, 4'h3, "R1 C3: 3");
        check_key(2'd0, 2'd3, 1'b1, 4'hA, "R1 C4: A");

        check_key(2'd1, 2'd0, 1'b1, 4'h4, "R2 C1: 4");
        check_key(2'd1, 2'd1, 1'b1, 4'h5, "R2 C2: 5");
        check_key(2'd1, 2'd2, 1'b1, 4'h6, "R2 C3: 6");
        check_key(2'd1, 2'd3, 1'b1, 4'hB, "R2 C4: B");

        check_key(2'd2, 2'd0, 1'b1, 4'h7, "R3 C1: 7");
        check_key(2'd2, 2'd1, 1'b1, 4'h8, "R3 C2: 8");
        check_key(2'd2, 2'd2, 1'b1, 4'h9, "R3 C3: 9");
        check_key(2'd2, 2'd3, 1'b1, 4'hC, "R3 C4: C");

        check_key(2'd3, 2'd0, 1'b1, 4'h9, "R4 C1: * fisico introduce 9");
        check_key(2'd3, 2'd1, 1'b1, 4'h0, "R4 C2: 0");
        check_key(2'd3, 2'd2, 1'b1, 4'hF, "R4 C3: # usa F reservado");
        check_key(2'd3, 2'd3, 1'b1, 4'hD, "R4 C4: D");

        check_key(2'd3, 2'd3, 1'b0, 4'h0, "key_detected=0 despues de D");

        $display("Total de pruebas: %0d", total_tests);
        $display("Errores: %0d", errors);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");
        $finish;
    end

endmodule

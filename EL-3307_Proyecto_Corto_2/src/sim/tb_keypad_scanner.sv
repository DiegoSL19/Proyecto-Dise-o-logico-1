module tb_keypad_scanner;
    timeunit 1ns;
    timeprecision 1ps;

    logic       clk;
    logic       reset;
    logic       tick_keypad;
    logic [3:0] rows;
    logic [3:0] columns;
    logic [1:0] row_index;
    logic [1:0] column_index;
    logic       key_detected;
    logic [3:0] pressed_rows [0:3];
    int unsigned total_tests;
    int unsigned errors;

    keypad_scanner dut (
        .clk          (clk),
        .reset        (reset),
        .tick_keypad  (tick_keypad),
        .rows         (rows),
        .columns      (columns),
        .row_index    (row_index),
        .column_index (column_index),
        .key_detected (key_detected)
    );

    initial begin
        clk = 1'b0;
        forever #18.518ns clk = ~clk;
    end

    // Modelo de la matriz: cada bit en 1 representa una tecla presionada.
    // Solo las teclas de la columna activa llevan sus filas a cero.
    always_comb begin
        case (columns)
            4'b1110: rows = ~pressed_rows[0];
            4'b1101: rows = ~pressed_rows[1];
            4'b1011: rows = ~pressed_rows[2];
            4'b0111: rows = ~pressed_rows[3];
            default: rows = 4'b1111;
        endcase
    end

    task automatic report (
        input logic  passed,
        input string description
    );
        total_tests += 1;
        if (passed === 1'b1) begin
            $display("PASS: %s", description);
        end else begin
            errors += 1;
            $error("FAIL: %s | columns=%b row_index=%0d column_index=%0d key_detected=%b",
                   description, columns, row_index, column_index, key_detected);
        end
    endtask

    task automatic scan_step (
        input logic [3:0] expected_columns,
        input logic [1:0] expected_row,
        input logic [1:0] expected_column,
        input logic       expected_detected,
        input string      description
    );
        @(negedge clk);
        tick_keypad = 1'b1;
        @(posedge clk);
        #1ns;
        report(({columns, row_index, column_index, key_detected} ===
                {expected_columns, expected_row, expected_column,
                 expected_detected}), description);

        @(negedge clk);
        tick_keypad = 1'b0;
        @(posedge clk);
        #1ns;
        report(({columns, row_index, column_index, key_detected} ===
                {expected_columns, expected_row, expected_column, 1'b0}),
               {description, " | sin tick mantiene barrido e indices"});
    endtask

    initial begin
        reset = 1'b1;
        tick_keypad = 1'b0;
        total_tests = 0;
        errors = 0;
        for (int unsigned column = 0; column < 4; column += 1)
            pressed_rows[column] = 4'b0000;

        @(posedge clk);
        #1ns;
        report(({columns, row_index, column_index, key_detected} ===
                {4'b1110, 2'd0, 2'd0, 1'b0}), "reset activa C1");

        @(negedge clk);
        reset = 1'b0;
        @(posedge clk);
        #1ns;
        report(({columns, row_index, column_index, key_detected} ===
                {4'b1110, 2'd0, 2'd0, 1'b0}), "sin tick conserva C1");

        scan_step(4'b1101, 2'd0, 2'd0, 1'b0, "primer tick avanza a C2");
        scan_step(4'b1011, 2'd0, 2'd1, 1'b0, "segundo tick avanza a C3");
        scan_step(4'b0111, 2'd0, 2'd2, 1'b0, "tercer tick avanza a C4");
        scan_step(4'b1110, 2'd0, 2'd3, 1'b0, "cuarto tick vuelve a C1");

        pressed_rows[0] = 4'b0001;
        scan_step(4'b1101, 2'd0, 2'd0, 1'b1, "tecla 1 en R1 C1");
        pressed_rows[0] = 4'b0000;

        pressed_rows[1] = 4'b0010;
        scan_step(4'b1011, 2'd1, 2'd1, 1'b1, "tecla 5 en R2 C2");
        pressed_rows[1] = 4'b0000;

        pressed_rows[2] = 4'b0100;
        scan_step(4'b0111, 2'd2, 2'd2, 1'b1, "tecla 9 en R3 C3");
        pressed_rows[2] = 4'b0000;

        pressed_rows[3] = 4'b1000;
        scan_step(4'b1110, 2'd3, 2'd3, 1'b1, "tecla D en R4 C4");
        pressed_rows[3] = 4'b0000;

        scan_step(4'b1101, 2'd0, 2'd0, 1'b0, "rows 1111 no detecta tecla");
        pressed_rows[1] = 4'b0011;
        scan_step(4'b1011, 2'd0, 2'd1, 1'b0, "rows 1100 rechaza dos filas activas");
        pressed_rows[1] = 4'b0000;

        pressed_rows[2] = 4'b1111;
        scan_step(4'b0111, 2'd0, 2'd2, 1'b0, "rows 0000 rechaza cuatro filas activas");
        pressed_rows[2] = 4'b0000;

        // Reset tiene prioridad incluso con tick y una tecla presionada.
        @(negedge clk);
        reset = 1'b1;
        tick_keypad = 1'b1;
        pressed_rows[3] = 4'b1000;
        @(posedge clk);
        #1ns;
        report(({columns, row_index, column_index, key_detected} ===
                {4'b1110, 2'd0, 2'd0, 1'b0}), "reset durante el barrido");

        $display("Total de pruebas: %0d", total_tests);
        $display("Errores: %0d", errors);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");
        $finish;
    end

endmodule

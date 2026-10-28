module tb_tick_generator;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int unsigned KEYPAD_DIV = 4;
    localparam int unsigned DISPLAY_DIV = 3;

    logic clk;
    logic reset;
    logic tick_keypad;
    logic tick_display;
    int unsigned total_tests;
    int unsigned errors;

    tick_generator #(
        .KEYPAD_DIV  (KEYPAD_DIV),
        .DISPLAY_DIV (DISPLAY_DIV)
    ) dut (
        .clk          (clk),
        .reset        (reset),
        .tick_keypad  (tick_keypad),
        .tick_display (tick_display)
    );

    // Unico reloj de prueba, de aproximadamente 27 MHz.
    initial begin
        clk = 1'b0;
        forever #18.518ns clk = ~clk;
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
            $error("FAIL: %s | tick_keypad=%b tick_display=%b",
                   description, tick_keypad, tick_display);
        end
    endtask

    task automatic check_cycles (
        input int unsigned cycles,
        input string       description
    );
        int unsigned next_keypad_cycle;
        int unsigned next_display_cycle;
        logic expected_keypad;
        logic expected_display;

        next_keypad_cycle = KEYPAD_DIV;
        next_display_cycle = DISPLAY_DIV;

        for (int unsigned cycle = 1; cycle <= cycles; cycle += 1) begin
            @(posedge clk);
            #1ns; // Esperar las asignaciones no bloqueantes.
            expected_keypad = (cycle == next_keypad_cycle);
            expected_display = (cycle == next_display_cycle);

            // Comprobar cada ciclo verifica los periodos, la duracion de un
            // ciclo, los ceros entre pulsos y las coincidencias en 12 y 24.
            report(({tick_keypad, tick_display} ===
                    {expected_keypad, expected_display}),
                   $sformatf("%s | ciclo=%0d | esperado keypad=%b display=%b",
                             description, cycle,
                             expected_keypad, expected_display));

            if (expected_keypad)
                next_keypad_cycle += KEYPAD_DIV;
            if (expected_display)
                next_display_cycle += DISPLAY_DIV;
        end
    endtask

    initial begin
        reset = 1'b1;
        total_tests = 0;
        errors = 0;

        @(posedge clk);
        #1ns;
        report(({tick_keypad, tick_display} === 2'b00), "reset inicial");

        @(negedge clk);
        reset = 1'b0;
        check_cycles(26, "periodos de 4 y 3 ciclos");

        // Tras 26 ciclos ambos contadores estan a mitad de sus periodos.
        @(negedge clk);
        reset = 1'b1;
        @(posedge clk);
        #1ns;
        report(({tick_keypad, tick_display} === 2'b00), "reset durante la cuenta");

        @(negedge clk);
        reset = 1'b0;
        check_cycles(14, "periodos reiniciados despues de reset");

        $display("Total de pruebas: %0d", total_tests);
        $display("Errores: %0d", errors);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");
        $finish;
    end

endmodule

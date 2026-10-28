module tb_debouncer;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int unsigned TEST_N = 4;
    localparam int unsigned STABILITY_CYCLES = 1 << (TEST_N - 1);

    logic clk;
    logic n_reset;
    logic button_in;
    logic DB_out;
    logic previous_db;
    int unsigned total_tests;
    int unsigned errors;
    int unsigned rising_changes;
    int unsigned falling_changes;

    debouncer #(
        .N(TEST_N)
    ) dut (
        .clk       (clk),
        .n_reset   (n_reset),
        .button_in (button_in),
        .DB_out    (DB_out)
    );

    // Reloj de prueba de aproximadamente 27 MHz.
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
            $display("PASS: %s | DB_out=%b", description, DB_out);
        end else begin
            errors += 1;
            $error("FAIL: %s | button_in=%b DB_out=%b",
                   description, button_in, DB_out);
        end
    endtask

    task automatic sample_and_check (
        input logic  expected,
        input string description
    );
        @(posedge clk);
        #1ns; // Esperar las asignaciones no bloqueantes.
        if ((previous_db === 1'b0) && (DB_out === 1'b1))
            rising_changes += 1;
        if ((previous_db === 1'b1) && (DB_out === 1'b0))
            falling_changes += 1;
        previous_db = DB_out;
        report((DB_out === expected), description);
    endtask

    task automatic drive_bounce (
        input logic  new_button,
        input logic  expected,
        input string description
    );
        @(negedge clk);
        button_in = new_button;
        // Dos ciclos por nivel: menos que el intervalo de estabilidad.
        sample_and_check(expected, {description, " | primer ciclo"});
        sample_and_check(expected, {description, " | segundo ciclo"});
    endtask

    task automatic wait_for_stable (
        input logic  previous_value,
        input logic  stable_value,
        input string description
    );
        // Esta task se llama tras dos ciclos con el nivel final de entrada.
        // El contador acaba de reiniciarse y ambas etapas tienen ese nivel.
        for (int unsigned cycle = 1; cycle <= STABILITY_CYCLES; cycle += 1)
            sample_and_check(previous_value,
                             $sformatf("%s | espera %0d", description, cycle));

        // El MSB ya esta en 1; este flanco actualiza DB_out.
        sample_and_check(stable_value, {description, " | salida actualizada"});
        repeat (4)
            sample_and_check(stable_value, {description, " | salida estable"});
    endtask

    initial begin
        n_reset = 1'b0;
        button_in = 1'b0;
        previous_db = 1'b0;
        total_tests = 0;
        errors = 0;
        rising_changes = 0;
        falling_changes = 0;

        sample_and_check(1'b0, "n_reset activo en bajo");
        @(negedge clk);
        n_reset = 1'b1;
        #1ns;
        report((DB_out === 1'b0), "liberar reset conserva salida en cero");

        drive_bounce(1'b0, 1'b0, "rebote de pulsacion: 0");
        drive_bounce(1'b1, 1'b0, "rebote de pulsacion: 1");
        drive_bounce(1'b0, 1'b0, "rebote de pulsacion: 0");
        drive_bounce(1'b1, 1'b0, "rebote de pulsacion: 1");
        drive_bounce(1'b0, 1'b0, "rebote de pulsacion: 0");
        drive_bounce(1'b1, 1'b0, "rebote de pulsacion: 1 final");
        wait_for_stable(1'b0, 1'b1, "pulsacion estable");
        report((rising_changes == 1) && (falling_changes == 0),
               $sformatf("pulsacion cambia una sola vez | subidas=%0d bajadas=%0d",
                         rising_changes, falling_changes));

        drive_bounce(1'b1, 1'b1, "rebote de liberacion: 1");
        drive_bounce(1'b0, 1'b1, "rebote de liberacion: 0");
        drive_bounce(1'b1, 1'b1, "rebote de liberacion: 1");
        drive_bounce(1'b0, 1'b1, "rebote de liberacion: 0");
        drive_bounce(1'b1, 1'b1, "rebote de liberacion: 1");
        drive_bounce(1'b0, 1'b1, "rebote de liberacion: 0 final");
        wait_for_stable(1'b1, 1'b0, "liberacion estable");
        report((rising_changes == 1) && (falling_changes == 1),
               $sformatf("liberacion cambia una sola vez | subidas=%0d bajadas=%0d",
                         rising_changes, falling_changes));

        // Llevar DB_out a 1 para comprobar un reset efectivo de la salida.
        drive_bounce(1'b1, 1'b0, "preparar nuevo reset");
        wait_for_stable(1'b0, 1'b1, "entrada alta antes del reset");
        @(negedge clk);
        n_reset = 1'b0;
        #1ns;
        report((DB_out === 1'b1), "reset sincrono espera el flanco");
        sample_and_check(1'b0, "nuevo reset activo en bajo con button_in=1");
        sample_and_check(1'b0, "reset mantenido conserva salida en cero");

        $display("Total de pruebas: %0d", total_tests);
        $display("Errores: %0d", errors);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");
        $finish;
    end

endmodule

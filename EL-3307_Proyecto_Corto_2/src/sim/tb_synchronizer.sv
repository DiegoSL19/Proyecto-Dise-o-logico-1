module tb_synchronizer;
    timeunit 1ns;
    timeprecision 1ps;

    logic       clk;
    logic       reset;
    logic [3:0] async_in;
    logic [3:0] sync_out;
    int unsigned total_tests;
    int unsigned errors;

    synchronizer dut (
        .clk      (clk),
        .reset    (reset),
        .async_in (async_in),
        .sync_out (sync_out)
    );

    // Periodo aproximado de 37.036 ns: reloj de prueba de 27 MHz.
    initial begin
        clk = 1'b0;
        forever #18.518ns clk = ~clk;
    end

    task automatic check_output (
        input logic [3:0] expected,
        input string      description
    );
        total_tests += 1;
        if (sync_out === expected) begin
            $display("PASS: %s | sync_out=%b", description, sync_out);
        end else begin
            errors += 1;
            $error("FAIL: %s | esperado=%b obtenido=%b",
                   description, expected, sync_out);
        end
    endtask

    task automatic change_and_check (
        input logic [3:0] new_value,
        input logic [3:0] previous_value,
        input string      description
    );
        // Cambiar la entrada entre flancos del reloj.
        @(negedge clk);
        #5ns;
        async_in = new_value;
        #1ns;
        check_output(previous_value,
                     {description, " | salida no cambia inmediatamente"});

        @(posedge clk);
        #1ns; // Esperar las asignaciones no bloqueantes.
        check_output(previous_value,
                     {description, " | primer flanco conserva salida anterior"});

        @(posedge clk);
        #1ns;
        check_output(new_value,
                     {description, " | segundo flanco entrega nueva salida"});
    endtask

    initial begin
        reset = 1'b1;
        async_in = 4'b1111;
        total_tests = 0;
        errors = 0;

        @(posedge clk);
        #1ns;
        check_output(4'b1111, "reset inicial");
        @(negedge clk);
        reset = 1'b0;

        change_and_check(4'b1110, 4'b1111, "entrada 1110");
        change_and_check(4'b1011, 4'b1110, "entrada 1011");
        change_and_check(4'b1111, 4'b1011, "regreso a 1111");
        change_and_check(4'b1101, 4'b1111, "valor distinto antes del reset");

        // Comprobar que el reset actua solamente en el flanco positivo.
        @(negedge clk);
        #5ns;
        reset = 1'b1;
        async_in = 4'b0000;
        #1ns;
        check_output(4'b1101, "reset sincrono espera el flanco");
        @(posedge clk);
        #1ns;
        check_output(4'b1111, "reset con entrada 0000");
        @(posedge clk);
        #1ns;
        check_output(4'b1111, "reset mantenido conserva 1111");

        // Ambas etapas deben haber sido reiniciadas a 1111.
        @(negedge clk);
        reset = 1'b0;
        @(posedge clk);
        #1ns;
        check_output(4'b1111, "primer flanco despues del reset");
        @(posedge clk);
        #1ns;
        check_output(4'b0000, "segundo flanco sincroniza 0000");

        $display("Total de pruebas: %0d", total_tests);
        $display("Errores: %0d", errors);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");
        $finish;
    end

endmodule

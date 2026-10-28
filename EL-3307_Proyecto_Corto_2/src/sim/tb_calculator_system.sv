module tb_calculator_system;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int unsigned TEST_DEBOUNCE_N = 6;
    localparam int unsigned TICK_INTERVAL = 3;
    localparam int unsigned SCAN_CYCLES = 4 * TICK_INTERVAL;
    localparam int unsigned DEBOUNCE_CYCLES = 1 << (TEST_DEBOUNCE_N - 1);
    localparam int unsigned WAIT_CYCLES = 4 * SCAN_CYCLES + DEBOUNCE_CYCLES + 8;
    // Referencia de comprobacion: C1 ocupa el nibble inferior de cada fila.
    // Fila 1: A321; fila 2: B654; fila 3: C987; fila 4: DF09 (* introduce 9).
    localparam logic [63:0] PHYSICAL_KEY_MAP = 64'hDF09_C987_B654_A321;

    logic clk;
    logic reset;
    logic tick_keypad;
    logic [3:0] rows_async;
    logic [3:0] columns;
    logic [9:0] operand_a;
    logic [9:0] operand_b;
    logic [9:0] magnitude;
    logic negative;
    logic result_valid;
    logic show_result;
    logic show_operand_b;
    logic [3:0] last_key_code;
    logic key_press;
    logic physical_pressed;
    logic [1:0] physical_row;
    logic [1:0] physical_column;
    logic [3:0] expected_key_code;
    logic allow_key_press;
    logic previous_key_press;
    logic previous_result_valid;
    logic [9:0] expected_a;
    logic [9:0] expected_b;
    logic [9:0] expected_magnitude;
    logic expected_negative;
    int unsigned key_pulse_count;
    int unsigned result_pulse_count;
    int unsigned total_tests;
    int unsigned errors;

    calculator_system #(
        .DEBOUNCE_N(TEST_DEBOUNCE_N)
    ) dut (
        .clk           (clk),
        .reset         (reset),
        .tick_keypad   (tick_keypad),
        .rows_async    (rows_async),
        .columns       (columns),
        .operand_a     (operand_a),
        .operand_b     (operand_b),
        .magnitude     (magnitude),
        .negative      (negative),
        .result_valid  (result_valid),
        .show_result   (show_result),
        .show_operand_b (show_operand_b),
        .last_key_code (last_key_code),
        .key_press     (key_press)
    );

    initial begin
        clk = 1'b0;
        forever #18.518ns clk = ~clk;
    end

    // Tick de un ciclo; dejar tres ciclos para sincronizar las filas.
    initial begin
        int unsigned tick_count;
        tick_count = 0;
        tick_keypad = 1'b0;
        forever begin
            @(negedge clk);
            if (reset) begin
                tick_count = 0;
                tick_keypad = 1'b0;
            end else if (tick_count == TICK_INTERVAL - 1) begin
                tick_count = 0;
                tick_keypad = 1'b1;
            end else begin
                tick_count += 1;
                tick_keypad = 1'b0;
            end
        end
    end

    always_comb begin
        rows_async = 4'b1111;
        if (physical_pressed && !columns[physical_column])
            rows_async[physical_row] = 1'b0;
    end

    task automatic report(input logic passed, input string description);
        total_tests += 1;
        if (passed === 1'b1)
            $display("PASS: %s", description);
        else begin
            errors += 1;
            $error("FAIL: %s | A=%0d B=%0d magnitude=%0d negative=%b key_press=%b result_valid=%b",
                   description, operand_a, operand_b, magnitude,
                   negative, key_press, result_valid);
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

    // Monitor continuo: solo salidas externas del DUT.
    initial begin
        key_pulse_count = 0;
        result_pulse_count = 0;
        previous_key_press = 1'b0;
        previous_result_valid = 1'b0;
        forever begin
            @(posedge clk);
            #1ns;
            if (reset) begin
                previous_key_press = 1'b0;
                previous_result_valid = 1'b0;
            end else begin
                if (key_press === 1'b1) begin
                    key_pulse_count += 1;
                    report(allow_key_press && (previous_key_press === 1'b0) &&
                           (last_key_code === expected_key_code),
                           "key_press permitido, de un ciclo y con codigo correcto");
                end else if (key_press !== 1'b0) begin
                    report(1'b0, "key_press desconocido");
                end

                if (result_valid === 1'b1) begin
                    result_pulse_count += 1;
                    report((previous_result_valid === 1'b0) &&
                           ({operand_a, operand_b, magnitude, negative, show_result} ===
                            {expected_a, expected_b, expected_magnitude,
                             expected_negative, 1'b1}),
                           "result_valid de un ciclo con resultado esperado");
                    check_display(1'b0, 1'b1,
                                  "result_valid coincide con visualizacion del resultado");
                end else if (result_valid !== 1'b0) begin
                    report(1'b0, "result_valid desconocido");
                end
                previous_key_press = key_press;
                previous_result_valid = result_valid;
            end
        end
    end

    task automatic wait_cycles(input int unsigned cycles);
        repeat (cycles) begin
            @(posedge clk);
            #2ns; // Leer despues del monitor y las asignaciones no bloqueantes.
        end
    endtask

    // Indices 0..3 corresponden a R1..R4 y C1..C4.
    task automatic press_physical_key (
        input logic [1:0] selected_row,
        input logic [1:0] selected_column
    );
        int unsigned before_count;
        int unsigned elapsed;
        string description;
        before_count = key_pulse_count;
        elapsed = 0;
        description = $sformatf("tecla fisica R%0d C%0d",
                                selected_row + 1, selected_column + 1);
        // Este codigo es solo una referencia; nunca se inyecta en el DUT.
        expected_key_code = PHYSICAL_KEY_MAP[({selected_row, selected_column} * 4) +: 4];
        allow_key_press = 1'b1;
        @(negedge clk);
        #1ns;
        physical_row = selected_row;
        physical_column = selected_column;
        physical_pressed = 1'b1;

        while ((key_pulse_count == before_count) && (elapsed < WAIT_CYCLES)) begin
            wait_cycles(1);
            elapsed += 1;
        end
        report((key_pulse_count == before_count + 1) && (key_press === 1'b1),
               {description, " | un pulso al presionar"});
        wait_cycles(1);
        report((key_press === 1'b0), {description, " | pulso dura un ciclo"});
        wait_cycles(WAIT_CYCLES);
        report((key_pulse_count == before_count + 1) && (key_press === 1'b0),
               {description, " | mantener no repite pulsos"});

        allow_key_press = 1'b0;
        @(negedge clk);
        #1ns;
        physical_pressed = 1'b0;
        wait_cycles(WAIT_CYCLES);
        report((key_pulse_count == before_count + 1) && (key_press === 1'b0),
               {description, " | liberar no genera pulsos"});
    endtask

    task automatic check_result (
        input int unsigned expected_pulses,
        input string description
    );
        report((result_pulse_count == expected_pulses) &&
               ({operand_a, operand_b, magnitude, negative, show_result, result_valid} ===
                {expected_a, expected_b, expected_magnitude,
                 expected_negative, 1'b1, 1'b0}), description);
        check_display(1'b0, 1'b1, {description, " | control de visualizacion"});
    endtask

    initial begin
        reset = 1'b1;
        physical_pressed = 1'b0;
        physical_row = 2'd0;
        physical_column = 2'd0;
        expected_key_code = 4'h0;
        allow_key_press = 1'b0;
        expected_a = 10'd0;
        expected_b = 10'd0;
        expected_magnitude = 10'd0;
        expected_negative = 1'b0;
        total_tests = 0;
        errors = 0;

        wait_cycles(2);
        report(({columns, operand_a, operand_b, magnitude, negative,
                 result_valid, show_result, last_key_code, key_press} ===
                {4'b1110, 10'd0, 10'd0, 10'd0, 1'b0,
                 1'b0, 1'b0, 4'h0, 1'b0}), "reset del sistema");
        check_display(1'b0, 1'b0, "reset del sistema: visualizacion de A");
        @(negedge clk);
        #1ns;
        reset = 1'b0;
        wait_cycles(WAIT_CYCLES);
        report((key_pulse_count == 0) && (result_pulse_count == 0),
               "sin tecla no hay pulsos");
        check_display(1'b0, 1'b0, "IDLE muestra A");

        expected_a = 10'd123;
        expected_b = 10'd45;
        expected_magnitude = 10'd78;
        expected_negative = 1'b0;
        press_physical_key(2'd0, 2'd0); // 1
        check_display(1'b0, 1'b0, "tecla fisica 1: muestra A");
        press_physical_key(2'd0, 2'd1); // 2
        check_display(1'b0, 1'b0, "tecla fisica 2: muestra A");
        press_physical_key(2'd0, 2'd2); // 3
        check_display(1'b0, 1'b0, "tecla fisica 3: muestra A");
        press_physical_key(2'd0, 2'd3); // A
        check_display(1'b1, 1'b0, "tecla fisica A: selecciona B");
        press_physical_key(2'd1, 2'd0); // 4
        check_display(1'b1, 1'b0, "tecla fisica 4: permanece en B");
        press_physical_key(2'd1, 2'd1); // 5
        check_display(1'b1, 1'b0, "tecla fisica 5: permanece en B");
        press_physical_key(2'd1, 2'd3); // B
        check_result(1, "PRUEBA 1: 123 y 45 producen magnitud 78 positiva");

        press_physical_key(2'd3, 2'd3); // D
        report(({operand_a, operand_b, show_result, result_valid} ===
                {10'd0, 10'd0, 1'b0, 1'b0}), "D limpia antes de PRUEBA 2");
        check_display(1'b0, 1'b0, "tecla fisica D: vuelve a mostrar A");
        expected_a = 10'd45;
        expected_b = 10'd123;
        expected_magnitude = 10'd78;
        expected_negative = 1'b1;
        press_physical_key(2'd1, 2'd0); // 4
        check_display(1'b0, 1'b0, "PRUEBA 2 comienza mostrando A");
        press_physical_key(2'd1, 2'd1); // 5
        press_physical_key(2'd0, 2'd3); // A
        press_physical_key(2'd0, 2'd0); // 1
        press_physical_key(2'd0, 2'd1); // 2
        press_physical_key(2'd0, 2'd2); // 3
        press_physical_key(2'd1, 2'd3); // B
        check_result(2, "PRUEBA 2: 45 y 123 producen magnitud 78 negativa");

        press_physical_key(2'd3, 2'd3); // D
        report(({operand_a, operand_b, show_result, result_valid} ===
                {10'd0, 10'd0, 1'b0, 1'b0}), "D limpia antes de PRUEBA 3");
        check_display(1'b0, 1'b0, "segundo D: vuelve a mostrar A");
        expected_a = 10'd999;
        expected_b = 10'd999;
        expected_magnitude = 10'd0;
        expected_negative = 1'b0;
        repeat (3) press_physical_key(2'd2, 2'd2); // 9, 9, 9
        press_physical_key(2'd0, 2'd3);            // A
        repeat (3) press_physical_key(2'd2, 2'd2); // 9, 9, 9
        press_physical_key(2'd1, 2'd3);            // B
        check_result(3, "PRUEBA 3: 999 y 999 producen cero sin signo negativo");

        report((key_pulse_count == 24), "24 pulsaciones fisicas producen 24 key_press");
        report((result_pulse_count == 3), "tres operaciones producen tres result_valid");
        $display("Total de pruebas: %0d", total_tests);
        $display("Errores: %0d", errors);
        $display("Cantidad de key_press: %0d", key_pulse_count);
        $display("Cantidad de result_valid: %0d", result_pulse_count);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");
        $finish;
    end

endmodule

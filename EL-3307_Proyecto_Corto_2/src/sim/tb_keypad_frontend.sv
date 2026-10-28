module tb_keypad_frontend;
    timeunit 1ns;
    timeprecision 1ps;

    // N=6: espera de 32 ciclos, mayor que un barrido de 12 ciclos.
    localparam int unsigned TEST_DEBOUNCE_N = 6;
    localparam int unsigned TICK_INTERVAL = 3;
    localparam int unsigned SCAN_CYCLES = 4 * TICK_INTERVAL;
    localparam int unsigned DEBOUNCE_CYCLES = 1 << (TEST_DEBOUNCE_N - 1);
    localparam int unsigned WAIT_CYCLES = 4 * SCAN_CYCLES + DEBOUNCE_CYCLES + 8;

    logic clk;
    logic reset;
    logic tick_keypad;
    logic [3:0] rows_async;
    logic [3:0] columns;
    logic [3:0] key_code;
    logic key_press;
    logic physical_pressed;
    logic [1:0] physical_row;
    logic [1:0] physical_column;
    logic [3:0] expected_code;
    logic allow_pulses;
    logic previous_press;
    int unsigned pulse_count;
    int unsigned total_tests;
    int unsigned errors;

    keypad_frontend #(
        .DEBOUNCE_N(TEST_DEBOUNCE_N)
    ) dut (
        .clk         (clk),
        .reset       (reset),
        .tick_keypad (tick_keypad),
        .rows_async  (rows_async),
        .columns     (columns),
        .key_code    (key_code),
        .key_press   (key_press)
    );

    initial begin
        clk = 1'b0;
        forever #18.518ns clk = ~clk;
    end

    // Enables de un ciclo. Tres ciclos permiten completar la sincronizacion.
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

    // Modelo de una tecla fisica y filas con pull-up.
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
            $error("FAIL: %s | key_code=%h key_press=%b pulsos=%0d",
                   description, key_code, key_press, pulse_count);
        end
    endtask

    // Contar cada ciclo alto permite detectar tambien pulsos de varios ciclos.
    initial begin
        previous_press = 1'b0;
        pulse_count = 0;
        forever begin
            @(posedge clk);
            #1ns;
            if (reset) begin
                previous_press = 1'b0;
            end else begin
                if (key_press === 1'b1) begin
                    pulse_count += 1;
                    report(allow_pulses && (previous_press === 1'b0) &&
                           (key_code === expected_code),
                           "pulso permitido, codigo correcto y duracion de un ciclo");
                end else if (key_press !== 1'b0) begin
                    report(1'b0, "key_press contiene un valor desconocido");
                end
                previous_press = key_press;
            end
        end
    end

    task automatic wait_cycles(input int unsigned cycles);
        repeat (cycles) begin
            @(posedge clk);
            #2ns; // Evaluar despues del monitor de pulsos.
        end
    endtask

    task automatic select_key (
        input logic present,
        input logic [1:0] selected_row,
        input logic [1:0] selected_column
    );
        @(negedge clk);
        #1ns;
        physical_row = selected_row;
        physical_column = selected_column;
        physical_pressed = present;
    endtask

    task automatic wait_one_pulse (
        input int unsigned before_count,
        input logic [3:0] code,
        input string description
    );
        int unsigned elapsed;
        elapsed = 0;
        while ((pulse_count == before_count) && (elapsed < WAIT_CYCLES)) begin
            wait_cycles(1);
            elapsed += 1;
        end
        report((pulse_count == before_count + 1) &&
               (key_code === code) && (key_press === 1'b1), description);
        wait_cycles(1);
        report((key_press === 1'b0), {description, " | pulso termina al siguiente ciclo"});
    endtask

    task automatic press_cycle (
        input logic [1:0] selected_row,
        input logic [1:0] selected_column,
        input logic [3:0] code,
        input string description
    );
        int unsigned before_count;
        before_count = pulse_count;
        expected_code = code;
        allow_pulses = 1'b1;
        select_key(1'b1, selected_row, selected_column);
        wait_one_pulse(before_count, code, description);
        wait_cycles(WAIT_CYCLES);
        report((pulse_count == before_count + 1) && (key_code === code) &&
               (key_press === 1'b0) && (dut.debounced_pressed === 1'b1),
               {description, " | mantener la tecla no repite pulsos"});

        allow_pulses = 1'b0;
        select_key(1'b0, selected_row, selected_column);
        wait_cycles(WAIT_CYCLES);
        report((pulse_count == before_count + 1) && (key_code === code) &&
               (key_press === 1'b0) && (dut.debounced_pressed === 1'b0),
               {description, " | liberacion reconocida sin nuevo pulso"});
    endtask

    initial begin
        int unsigned before_bounce;
        int unsigned align_cycles;
        reset = 1'b1;
        physical_pressed = 1'b0;
        physical_row = 2'd0;
        physical_column = 2'd0;
        expected_code = 4'h0;
        allow_pulses = 1'b0;
        total_tests = 0;
        errors = 0;

        wait_cycles(2);
        report(({columns, key_code, key_press} === {4'b1110, 4'h0, 1'b0}),
               "CASO 1: reset inicia C1 y no genera pulsos");
        @(negedge clk);
        #1ns;
        reset = 1'b0;
        wait_cycles(WAIT_CYCLES);
        report((pulse_count == 0), "sin tecla no hay pulsos");

        press_cycle(2'd1, 2'd1, 4'h5, "CASOS 2, 3 y 4: presionar, mantener y liberar 5");
        press_cycle(2'd1, 2'd1, 4'h5, "CASO 5: volver a presionar 5");
        press_cycle(2'd0, 2'd3, 4'hA, "CASO 6: tecla A en R1 C4");
        press_cycle(2'd3, 2'd1, 4'h0, "CASO 7: tecla 0 en R4 C2");
        press_cycle(2'd3, 2'd3, 4'hD, "CASO 8: tecla D en R4 C4");

        before_bounce = pulse_count;
        expected_code = 4'h5;
        // Comenzar los rebotes en el limite de un barrido completo.
        align_cycles = 0;
        do begin
            wait_cycles(1);
            align_cycles += 1;
        end while ((align_cycles < WAIT_CYCLES) &&
                   !((columns === 4'b1110) &&
                     (dut.event_builder.scan_count === 2'd0) &&
                     (dut.tick_keypad_delayed === 1'b0)));
        report((columns === 4'b1110) &&
               (dut.event_builder.scan_count === 2'd0) &&
               (dut.tick_keypad_delayed === 1'b0),
               "CASO 9: inicio alineado con el barrido");

        // Cada rebote dura un barrido de 12 ciclos, menos que los 32 de espera.
        for (int unsigned bounce = 0; bounce < 6; bounce += 1) begin
            select_key(bounce[0], 2'd1, 2'd1);
            wait_cycles(SCAN_CYCLES);
            report((pulse_count == before_bounce),
                   $sformatf("CASO 9: sin pulsos durante rebote %0d", bounce));
        end
        allow_pulses = 1'b1;
        wait_one_pulse(before_bounce, 4'h5, "CASO 9: tecla estable despues del rebote");
        wait_cycles(WAIT_CYCLES);
        report((pulse_count == before_bounce + 1), "CASO 9: solo un pulso al estabilizar");
        allow_pulses = 1'b0;
        select_key(1'b0, 2'd1, 2'd1);
        wait_cycles(WAIT_CYCLES);
        report((pulse_count == before_bounce + 1) &&
               (dut.debounced_pressed === 1'b0), "CASO 9: liberar sin pulsos adicionales");
        report((pulse_count == 6), "seis pulsaciones completas producen seis pulsos");

        $display("Total de pruebas: %0d", total_tests);
        $display("Errores: %0d", errors);
        $display("Cantidad de pulsos detectados: %0d", pulse_count);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");
        $finish;
    end

endmodule

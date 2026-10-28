module tb_keypad_event;
    timeunit 1ns;
    timeprecision 1ps;

    logic       clk;
    logic       reset;
    logic       tick_keypad;
    logic [3:0] key_code;
    logic       key_valid;
    logic [3:0] latched_key_code;
    logic       raw_pressed;
    int unsigned total_tests;
    int unsigned errors;

    keypad_event dut (
        .clk              (clk),
        .reset            (reset),
        .tick_keypad      (tick_keypad),
        .key_code         (key_code),
        .key_valid        (key_valid),
        .latched_key_code (latched_key_code),
        .raw_pressed      (raw_pressed)
    );

    initial begin
        clk = 1'b0;
        forever #18.518ns clk = ~clk;
    end

    // expected contiene {raw_pressed, latched_key_code}.
    task automatic check_outputs (
        input logic [4:0] expected,
        input string      description
    );
        total_tests += 1;
        if ({raw_pressed, latched_key_code} === expected) begin
            $display("PASS: %s | raw_pressed=%b code=%h",
                     description, raw_pressed, latched_key_code);
        end else begin
            errors += 1;
            $error("FAIL: %s | esperado=(%b,%h) obtenido=(%b,%h)",
                   description, expected[4], expected[3:0],
                   raw_pressed, latched_key_code);
        end
    endtask

    task automatic scan_sample (
        input logic       valid,
        input logic [3:0] code,
        input logic [4:0] expected,
        input string      description
    );
        @(negedge clk);
        tick_keypad = 1'b1;
        key_valid = valid;
        key_code = code;
        @(posedge clk);
        #1ns;
        check_outputs(expected, description);

        @(negedge clk);
        tick_keypad = 1'b0;
        key_valid = 1'b0;
        key_code = 4'h0;
        @(posedge clk);
        #1ns;
        check_outputs(expected, {description, " | estable entre ticks"});
    endtask

    task automatic run_scan (
        input logic [3:0]  detections,
        input logic [15:0] codes,
        input logic [4:0]  expected_before,
        input logic [4:0]  expected_after,
        input string       description
    );
        // Bit 0 y nibble inferior corresponden a C1; bit 3 y superior a C4.
        for (int unsigned sample = 0; sample < 4; sample += 1) begin
            scan_sample(detections[sample], codes[(sample * 4) +: 4],
                        (sample == 3) ? expected_after : expected_before,
                        $sformatf("%s | C%0d", description, sample + 1));
        end
    endtask

    initial begin
        reset = 1'b1;
        tick_keypad = 1'b0;
        key_code = 4'h0;
        key_valid = 1'b0;
        total_tests = 0;
        errors = 0;

        @(posedge clk);
        #1ns;
        check_outputs(5'b0_0000, "reset");
        @(negedge clk);
        reset = 1'b0;

        run_scan(4'b0000, 16'h0000, 5'b0_0000, 5'b0_0000,
                 "CASO 1: ninguna tecla");
        run_scan(4'b0010, 16'h0050, 5'b0_0000, 5'b1_0101,
                 "CASO 2: tecla 5 solo en C2");
        run_scan(4'b0010, 16'h0050, 5'b1_0101, 5'b1_0101,
                 "CASO 3: tecla 5 mantenida");
        run_scan(4'b0000, 16'h0000, 5'b1_0101, 5'b0_0101,
                 "CASO 4: liberacion tras barrido vacio");
        run_scan(4'b1000, 16'hA000, 5'b0_0101, 5'b1_1010,
                 "CASO 5: tecla A en C4");
        run_scan(4'b0011, 16'h0051, 5'b1_1010, 5'b0_1010,
                 "CASO 6: codigos 1 y 5 invalidan el barrido");

        run_scan(4'b0100, 16'h0300, 5'b0_1010, 5'b1_0011,
                 "barrido valido despues de multiples teclas");
        run_scan(4'b1001, 16'h5001, 5'b1_0011, 5'b0_0011,
                 "segundo codigo distinto aparece en C4");
        run_scan(4'b0110, 16'h0550, 5'b0_0011, 5'b1_0101,
                 "repetir el mismo codigo no crea ambiguedad");

        scan_sample(1'b1, 4'h9, 5'b1_0101, "barrido parcial antes de reset");
        scan_sample(1'b1, 4'h2, 5'b1_0101, "ambiguedad parcial antes de reset");
        @(negedge clk);
        reset = 1'b1;
        tick_keypad = 1'b1;
        key_valid = 1'b1;
        key_code = 4'hF;
        @(posedge clk);
        #1ns;
        check_outputs(5'b0_0000, "reset tiene prioridad sobre muestra valida");
        @(negedge clk);
        reset = 1'b0;
        tick_keypad = 1'b0;
        key_valid = 1'b0;

        run_scan(4'b1000, 16'hA000, 5'b0_0000, 5'b1_1010,
                 "reset reinicia contador y banderas del barrido");

        $display("Total de pruebas: %0d", total_tests);
        $display("Errores: %0d", errors);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");
        $finish;
    end

endmodule

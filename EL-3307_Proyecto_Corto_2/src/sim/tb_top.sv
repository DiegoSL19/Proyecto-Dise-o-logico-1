module tb_top;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int unsigned TEST_KEYPAD_DIV = 3;
    localparam int unsigned TEST_DEBOUNCE_N = 6;
    localparam int unsigned TEST_DISPLAY_MUX_N = 4;
    localparam int unsigned SCAN_CYCLES = 4 * TEST_KEYPAD_DIV;
    localparam int unsigned DEBOUNCE_CYCLES = 1 << (TEST_DEBOUNCE_N - 1);
    localparam int unsigned KEY_WAIT_CYCLES = 4 * SCAN_CYCLES + DEBOUNCE_CYCLES + 8;
    localparam int unsigned DISPLAY_FRAME_CYCLES = 1 << TEST_DISPLAY_MUX_N;
    localparam int unsigned DISPLAY_TIMEOUT = 2 * DISPLAY_FRAME_CYCLES;
    localparam int unsigned RESULT_WAIT_CYCLES = 2 * DISPLAY_FRAME_CYCLES;

    localparam logic [7:0] SEG_0 = 8'b0_1111110;
    localparam logic [7:0] SEG_1 = 8'b0_0110000;
    localparam logic [7:0] SEG_2 = 8'b0_1101101;
    localparam logic [7:0] SEG_3 = 8'b0_1111001;
    localparam logic [7:0] SEG_4 = 8'b0_0110011;
    localparam logic [7:0] SEG_5 = 8'b0_1011011;
    localparam logic [7:0] SEG_7 = 8'b0_1110000;
    localparam logic [7:0] SEG_8 = 8'b0_1111111;
    localparam logic [7:0] SEG_9 = 8'b0_1111011;
    localparam logic [7:0] BLANK = 8'b0_0000000;
    localparam logic [7:0] MINUS = 8'b0_0000001;

    logic clk;
    logic reset_n;
    logic [3:0] rows;
    logic [3:0] columns;
    logic [3:0] an;
    logic [7:0] sseg;
    logic physical_pressed;
    logic [1:0] physical_row;
    logic [1:0] physical_column;
    int unsigned total_tests;
    int unsigned errors;

    // Ejecutar desde src/build; la ROM se carga desde ../design/bcdtable.txt.
    top #(
        .KEYPAD_DIV    (TEST_KEYPAD_DIV),
        .DEBOUNCE_N    (TEST_DEBOUNCE_N),
        .DISPLAY_MUX_N (TEST_DISPLAY_MUX_N)
    ) dut (
        .clk     (clk),
        .reset_n (reset_n),
        .rows    (rows),
        .columns (columns),
        .an      (an),
        .sseg    (sseg)
    );

    initial begin
        clk = 1'b0;
        forever #18.518ns clk = ~clk;
    end

    // Matriz fisica con pull-up; la columna seleccionada es activa en bajo.
    always_comb begin
        rows = 4'b1111;
        if (physical_pressed && !columns[physical_column])
            rows[physical_row] = 1'b0;
    end

    task automatic report (
        input logic passed,
        input string description
    );
        total_tests += 1;
        if (passed === 1'b1)
            $display("PASS: %s", description);
        else begin
            errors += 1;
            $error("FAIL: %s | columns=%b an=%b sseg=%b",
                   description, columns, an, sseg);
        end
    endtask

    task automatic wait_cycles(input int unsigned cycles);
        repeat (cycles) begin
            @(posedge clk);
            #2ns;
        end
    endtask

    // Indices 0..3 corresponden a R1..R4 y C1..C4.
    // Esperas suficientes para barrido, debounce, captura y liberacion.
    task automatic press_physical_key (
        input logic [1:0] selected_row,
        input logic [1:0] selected_column
    );
        @(negedge clk);
        #1ns;
        physical_row = selected_row;
        physical_column = selected_column;
        physical_pressed = 1'b1;
        wait_cycles(2 * KEY_WAIT_CYCLES);

        @(negedge clk);
        #1ns;
        physical_pressed = 1'b0;
        wait_cycles(KEY_WAIT_CYCLES);
    endtask

    // Comprobacion solo mediante an y sseg, con timeout de dos refrescos.
    task automatic check_digit (
        input logic [3:0] selected_an,
        input logic [7:0] expected_sseg,
        input string description
    );
        int unsigned elapsed;
        logic found;

        elapsed = 0;
        found = 1'b0;
        while (!found && (elapsed < DISPLAY_TIMEOUT)) begin
            @(posedge clk);
            #1ns;
            elapsed += 1;
            found = (an === selected_an);
        end
        report(found && (sseg === expected_sseg),
               $sformatf("%s | an esperado=%b sseg esperado=%b",
                         description, selected_an, expected_sseg));
    endtask

    task automatic check_display (
        input logic [7:0] expected_sign,
        input logic [7:0] expected_hundreds,
        input logic [7:0] expected_tens,
        input logic [7:0] expected_units,
        input string description
    );
        check_digit(4'b0001, expected_units, {description, " | unidades"});
        check_digit(4'b0010, expected_tens, {description, " | decenas"});
        check_digit(4'b0100, expected_hundreds, {description, " | centenas"});
        check_digit(4'b1000, expected_sign, {description, " | signo"});
    endtask

    initial begin
        reset_n = 1'b0;
        physical_pressed = 1'b0;
        physical_row = 2'd0;
        physical_column = 2'd0;
        total_tests = 0;
        errors = 0;

        wait_cycles(2);
        report(({columns, an, sseg} === {4'b1110, 4'b0001, SEG_0}),
               "reset inicial del sistema completo");
        @(negedge clk);
        #1ns;
        reset_n = 1'b1;
        wait_cycles(KEY_WAIT_CYCLES);
        check_display(BLANK, BLANK, BLANK, SEG_0, "despues de reset: 0");

        press_physical_key(2'd0, 2'd0); // 1
        check_display(BLANK, BLANK, BLANK, SEG_1, "PRUEBA 1: A=1");
        press_physical_key(2'd0, 2'd1); // 2
        check_display(BLANK, BLANK, SEG_1, SEG_2, "PRUEBA 1: A=12");
        press_physical_key(2'd0, 2'd2); // 3
        check_display(BLANK, SEG_1, SEG_2, SEG_3, "PRUEBA 1: A=123");
        press_physical_key(2'd0, 2'd3); // A
        check_display(BLANK, BLANK, BLANK, SEG_0, "PRUEBA 1: A selecciona B=0");
        press_physical_key(2'd1, 2'd0); // 4
        check_display(BLANK, BLANK, BLANK, SEG_4, "PRUEBA 1: B=4");
        press_physical_key(2'd1, 2'd1); // 5
        check_display(BLANK, BLANK, SEG_4, SEG_5, "PRUEBA 1: B=45");
        press_physical_key(2'd1, 2'd3); // B
        wait_cycles(RESULT_WAIT_CYCLES);
        check_display(BLANK, BLANK, SEG_7, SEG_8, "PRUEBA 1: resultado 78");

        press_physical_key(2'd3, 2'd3); // D
        check_display(BLANK, BLANK, BLANK, SEG_0, "D prepara PRUEBA 2: 0");
        press_physical_key(2'd1, 2'd0); // 4
        press_physical_key(2'd1, 2'd1); // 5
        check_display(BLANK, BLANK, SEG_4, SEG_5, "PRUEBA 2: A=45");
        press_physical_key(2'd0, 2'd3); // A
        press_physical_key(2'd0, 2'd0); // 1
        press_physical_key(2'd0, 2'd1); // 2
        press_physical_key(2'd0, 2'd2); // 3
        check_display(BLANK, SEG_1, SEG_2, SEG_3, "PRUEBA 2: B=123");
        press_physical_key(2'd1, 2'd3); // B
        wait_cycles(RESULT_WAIT_CYCLES);
        check_display(MINUS, BLANK, SEG_7, SEG_8, "PRUEBA 2: resultado -78");

        press_physical_key(2'd3, 2'd3); // D
        check_display(BLANK, BLANK, BLANK, SEG_0, "D prepara PRUEBA 3: 0 sin signo");
        repeat (3) press_physical_key(2'd2, 2'd2); // 9, 9, 9
        check_display(BLANK, SEG_9, SEG_9, SEG_9, "PRUEBA 3: A=999 sin signo");
        press_physical_key(2'd0, 2'd3);            // A
        repeat (3) press_physical_key(2'd2, 2'd2); // 9, 9, 9
        check_display(BLANK, SEG_9, SEG_9, SEG_9, "PRUEBA 3: B=999 sin signo");
        press_physical_key(2'd1, 2'd3);            // B
        wait_cycles(RESULT_WAIT_CYCLES);
        check_display(BLANK, BLANK, BLANK, SEG_0, "PRUEBA 3: resultado 0");

        $display("Total de pruebas: %0d", total_tests);
        $display("Errores: %0d", errors);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");
        $finish;
    end

endmodule

module tb_calculator_display;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int unsigned TEST_MUX_N = 4;
    localparam int unsigned WAIT_LIMIT = 2 * (1 << TEST_MUX_N);
    localparam logic [7:0] SEG_0 = 8'b1_0000001;
    localparam logic [7:0] SEG_1 = 8'b1_1001111;
    localparam logic [7:0] SEG_2 = 8'b1_0010010;
    localparam logic [7:0] SEG_3 = 8'b1_0000110;
    localparam logic [7:0] SEG_4 = 8'b1_1001100;
    localparam logic [7:0] SEG_5 = 8'b1_0100100;
    localparam logic [7:0] SEG_7 = 8'b1_0001111;
    localparam logic [7:0] SEG_8 = 8'b1_0000000;
    localparam logic [7:0] SEG_9 = 8'b1_0000100;
    localparam logic [7:0] BLANK = 8'b1_1111111;
    localparam logic [7:0] MINUS = 8'b1_1111110;

    logic clk;
    logic reset;
    logic [9:0] operand_a;
    logic [9:0] operand_b;
    logic [9:0] magnitude;
    logic negative;
    logic show_result;
    logic show_operand_b;
    logic [3:0] an;
    logic [7:0] sseg;
    int unsigned total_tests;
    int unsigned errors;

    // Ejecutar desde src/build; la ROM se carga desde ../design/bcdtable.txt.
    calculator_display #(
        .MUX_N(TEST_MUX_N)
    ) dut (
        .clk            (clk),
        .reset          (reset),
        .operand_a      (operand_a),
        .operand_b      (operand_b),
        .magnitude      (magnitude),
        .negative       (negative),
        .show_result    (show_result),
        .show_operand_b (show_operand_b),
        .an             (an),
        .sseg           (sseg)
    );

    initial begin
        clk = 1'b0;
        forever #18.518ns clk = ~clk;
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
            $error("FAIL: %s | an=%b sseg=%b", description, an, sseg);
        end
    endtask

    // Espera acotada: un fallo del multiplexor no bloquea la simulacion.
    // Solo se observan an y sseg, sin referencias jerarquicas al DUT.
    task automatic check_digit (
        input logic [3:0] selected_an,
        input logic [7:0] expected_sseg,
        input string description
    );
        int unsigned elapsed;
        logic found;

        elapsed = 0;
        found = 1'b0;
        while (!found && (elapsed < WAIT_LIMIT)) begin
            @(posedge clk);
            #1ns; // Esperar el contador y la propagacion combinacional.
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
        check_digit(4'b1110, expected_units, {description, " | unidades"});
        check_digit(4'b1101, expected_tens, {description, " | decenas"});
        check_digit(4'b1011, expected_hundreds, {description, " | centenas"});
        check_digit(4'b0111, expected_sign, {description, " | signo"});
    endtask

    initial begin
        reset = 1'b1;
        operand_a = 10'd123;
        operand_b = 10'd45;
        magnitude = 10'd78;
        negative = 1'b1; // Un signo anterior no debe aparecer al ingresar A o B.
        show_result = 1'b0;
        show_operand_b = 1'b0;
        total_tests = 0;
        errors = 0;

        @(posedge clk);
        #1ns;
        report(({an, sseg} === {4'b1110, SEG_3}),
               "reset selecciona las unidades de A");
        @(negedge clk);
        reset = 1'b0;
        check_display(BLANK, SEG_1, SEG_2, SEG_3,
                      "CASO 1: A=123 sin signo aunque negative=1");

        @(negedge clk);
        show_operand_b = 1'b1;
        check_display(BLANK, BLANK, SEG_4, SEG_5,
                      "CASO 2: B=45 sin signo aunque negative=1");

        @(negedge clk);
        show_result = 1'b1;
        show_operand_b = 1'b0;
        negative = 1'b0;
        check_display(BLANK, BLANK, SEG_7, SEG_8,
                      "CASO 3: resultado positivo 78");

        @(negedge clk);
        negative = 1'b1;
        check_display(MINUS, BLANK, SEG_7, SEG_8,
                      "CASO 4: resultado negativo 78");

        @(negedge clk);
        magnitude = 10'd0;
        negative = 1'b0;
        check_display(BLANK, BLANK, BLANK, SEG_0,
                      "CASO 5: cero conserva las unidades");

        @(negedge clk);
        magnitude = 10'd999;
        check_display(BLANK, SEG_9, SEG_9, SEG_9,
                      "CASO 6: resultado 999");

        @(negedge clk);
        operand_b = 10'd45;
        magnitude = 10'd377;
        show_operand_b = 1'b1;
        check_display(BLANK, SEG_3, SEG_7, SEG_7,
                      "CASO 7: resultado 377 tiene prioridad sobre B=45");

        @(negedge clk);
        operand_a = 10'd5;
        show_result = 1'b0;
        show_operand_b = 1'b0;
        negative = 1'b1;
        check_display(BLANK, BLANK, BLANK, SEG_5,
                      "ADICIONAL: A=5 sin ceros a la izquierda ni signo");

        @(negedge clk);
        operand_b = 10'd10;
        show_operand_b = 1'b1;
        check_display(BLANK, BLANK, SEG_1, SEG_0,
                      "ADICIONAL: B=10 conserva las decenas");

        @(negedge clk);
        magnitude = 10'd100;
        show_result = 1'b1;
        negative = 1'b0;
        check_display(BLANK, SEG_1, SEG_0, SEG_0,
                      "ADICIONAL: resultado 100 conserva las centenas");

        @(negedge clk);
        show_result = 1'b0;
        show_operand_b = 1'b0;
        operand_a = 10'd10;
        check_display(BLANK, BLANK, SEG_1, SEG_0,
                      "ADICIONAL: A=10 conserva las decenas");

        @(negedge clk);
        operand_a = 10'd100;
        check_display(BLANK, SEG_1, SEG_0, SEG_0,
                      "ADICIONAL: A=100 conserva centenas y cero en decenas");

        @(negedge clk);
        operand_a = 10'd101;
        check_display(BLANK, SEG_1, SEG_0, SEG_1,
                      "ADICIONAL: A=101 conserva el cero intermedio");

        @(negedge clk);
        operand_a = 10'd110;
        check_display(BLANK, SEG_1, SEG_1, SEG_0,
                      "ADICIONAL: A=110 conserva centenas y decenas");

        $display("Total de pruebas: %0d", total_tests);
        $display("Errores: %0d", errors);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");
        $finish;
    end

endmodule

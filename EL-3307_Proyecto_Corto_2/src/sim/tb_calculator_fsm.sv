module tb_calculator_fsm;
    timeunit 1ns;
    timeprecision 1ps;

    logic       clk;
    logic       reset;
    logic       key_valid;
    logic [3:0] key_code;
    logic       load_a;
    logic       load_b;
    logic       clear_a;
    logic       clear_b;
    logic       calculate;
    logic       show_result;
    logic       show_operand_b;
    logic [9:0] value_a;
    logic [9:0] value_b;
    int unsigned total_tests;
    int unsigned errors;

    calculator_fsm dut (
        .clk         (clk),
        .reset       (reset),
        .key_valid   (key_valid),
        .key_code    (key_code),
        .load_a      (load_a),
        .load_b      (load_b),
        .clear_a     (clear_a),
        .clear_b     (clear_b),
        .calculate   (calculate),
        .show_result (show_result),
        .show_operand_b (show_operand_b)
    );

    // Reutilizar los registros existentes para comprobar la captura real.
    operand_register register_a (
        .clk        (clk),
        .reset      (reset),
        .clear      (clear_a),
        .load_digit (load_a),
        .digit      (key_code),
        .value      (value_a)
    );

    operand_register register_b (
        .clk        (clk),
        .reset      (reset),
        .clear      (clear_b),
        .load_digit (load_b),
        .digit      (key_code),
        .value      (value_b)
    );

    initial begin
        clk = 1'b0;
        forever #18.518ns clk = ~clk;
    end

    // Orden del vector: clear_a, clear_b, load_a, load_b, calculate, show_result.
    task automatic check_outputs (
        input logic [5:0] expected,
        input string      description
    );
        total_tests += 1;
        if ({clear_a, clear_b, load_a, load_b, calculate, show_result}
            === expected) begin
            $display("PASS: %s", description);
        end else begin
            errors += 1;
            $error("FAIL: %s | salidas esperadas=%b obtenidas=%b",
                   description, expected,
                   {clear_a, clear_b, load_a, load_b, calculate, show_result});
        end
    endtask

    task automatic check_display (
        input logic [2:0] expected_state,
        input string description
    );
        logic expected_operand_b;
        logic expected_result;

        expected_operand_b = 1'b0;
        expected_result = 1'b0;
        if (!reset) begin
            case (expected_state)
                dut.INPUT_B, dut.CALCULATE: expected_operand_b = 1'b1;
                dut.SHOW_RESULT: expected_result = 1'b1;
                default: begin
                    // IDLE e INPUT_A conservan ambos valores en cero.
                end
            endcase
        end

        total_tests += 1;
        if ({show_operand_b, show_result} === {expected_operand_b, expected_result})
            $display("PASS: %s | show_operand_b=%b show_result=%b",
                     description, show_operand_b, show_result);
        else begin
            errors += 1;
            $error("FAIL: %s | visualizacion esperada=%b obtenida=%b",
                   description, {expected_operand_b, expected_result},
                   {show_operand_b, show_result});
        end
    endtask

    task automatic check_registered (
        input logic [2:0] expected_state,
        input logic [9:0] expected_a,
        input logic [9:0] expected_b,
        input string      description
    );
        total_tests += 1;
        if ((dut.state === expected_state) &&
            (value_a === expected_a) && (value_b === expected_b)) begin
            $display("PASS: %s | estado=%0d A=%0d B=%0d",
                     description, dut.state, value_a, value_b);
        end else begin
            errors += 1;
            $error("FAIL: %s | esperado=(%0d,%0d,%0d) obtenido=(%0d,%0d,%0d)",
                   description, expected_state, expected_a, expected_b,
                   dut.state, value_a, value_b);
        end
        check_display(expected_state, {description, " | control de visualizacion"});
    endtask

    task automatic key_cycle (
        input logic       valid,
        input logic [3:0] code,
        input logic [5:0] outputs_before,
        input logic [2:0] state_after,
        input logic [5:0] outputs_after,
        input logic [9:0] expected_a,
        input logic [9:0] expected_b,
        input string      description
    );
        @(negedge clk);
        key_valid = valid;
        key_code = code;
        #1ns;
        check_outputs(outputs_before, {description, " | antes del flanco"});

        @(posedge clk);
        #1ns;
        check_outputs(outputs_after, {description, " | despues del flanco"});
        check_registered(state_after, expected_a, expected_b, description);
    endtask

    initial begin
        reset       = 1'b1;
        key_valid   = 1'b0;
        key_code    = 4'd0;
        total_tests = 0;
        errors      = 0;

        @(posedge clk);
        #1ns;
        check_outputs(6'b110000, "reset limpia ambos operandos");
        check_registered(dut.IDLE, 10'd0, 10'd0, "reset establece IDLE");

        @(negedge clk);
        reset = 1'b0;

        key_cycle(1'b0, 4'd3, 6'b110000, dut.IDLE, 6'b110000,
                  10'd0, 10'd0, "IDLE sin tecla valida");
        key_cycle(1'b1, 4'hF, 6'b110000, dut.IDLE, 6'b110000,
                  10'd0, 10'd0, "IDLE ignora tecla no numerica");
        key_cycle(1'b1, 4'hD, 6'b110000, dut.IDLE, 6'b110000,
                  10'd0, 10'd0, "D limpia desde IDLE");
        key_cycle(1'b1, 4'd1, 6'b011000, dut.INPUT_A, 6'b001000,
                  10'd1, 10'd0, "primer digito se almacena sin clear_a");
        key_cycle(1'b1, 4'd2, 6'b001000, dut.INPUT_A, 6'b001000,
                  10'd12, 10'd0, "load_a agrega segundo digito");
        key_cycle(1'b1, 4'hD, 6'b110000, dut.IDLE, 6'b110000,
                  10'd0, 10'd0, "1 -> 2 -> D limpia desde INPUT_A");
        key_cycle(1'b1, 4'd1, 6'b011000, dut.INPUT_A, 6'b001000,
                  10'd1, 10'd0, "nueva captura de A tras D");
        key_cycle(1'b1, 4'd2, 6'b001000, dut.INPUT_A, 6'b001000,
                  10'd12, 10'd0, "A vuelve a 12");
        key_cycle(1'b0, 4'd3, 6'b000000, dut.INPUT_A, 6'b000000,
                  10'd12, 10'd0, "INPUT_A conserva sin key_valid");
        key_cycle(1'b1, 4'hC, 6'b000000, dut.INPUT_A, 6'b000000,
                  10'd12, 10'd0, "INPUT_A ignora C");
        key_cycle(1'b1, 4'hA, 6'b000000, dut.INPUT_B, 6'b000000,
                  10'd12, 10'd0, "A selecciona INPUT_B");
        key_cycle(1'b1, 4'd4, 6'b000100, dut.INPUT_B, 6'b000100,
                  10'd12, 10'd4, "load_b agrega primer digito");
        key_cycle(1'b1, 4'd5, 6'b000100, dut.INPUT_B, 6'b000100,
                  10'd12, 10'd45, "load_b agrega segundo digito");
        key_cycle(1'b1, 4'hD, 6'b110000, dut.IDLE, 6'b110000,
                  10'd0, 10'd0, "D limpia ambos operandos desde INPUT_B");
        key_cycle(1'b1, 4'd1, 6'b011000, dut.INPUT_A, 6'b001000,
                  10'd1, 10'd0, "INPUT_B limpiado: nuevo A");
        key_cycle(1'b1, 4'd2, 6'b001000, dut.INPUT_A, 6'b001000,
                  10'd12, 10'd0, "INPUT_B limpiado: A=12");
        key_cycle(1'b1, 4'hA, 6'b000000, dut.INPUT_B, 6'b000000,
                  10'd12, 10'd0, "INPUT_B limpiado: A selecciona B");
        key_cycle(1'b1, 4'd4, 6'b000100, dut.INPUT_B, 6'b000100,
                  10'd12, 10'd4, "INPUT_B limpiado: B=4");
        key_cycle(1'b1, 4'd5, 6'b000100, dut.INPUT_B, 6'b000100,
                  10'd12, 10'd45, "INPUT_B limpiado: B=45");
        key_cycle(1'b0, 4'hB, 6'b000000, dut.INPUT_B, 6'b000000,
                  10'd12, 10'd45, "B sin key_valid no cambia estado");
        key_cycle(1'b1, 4'hB, 6'b000000, dut.CALCULATE, 6'b000010,
                  10'd12, 10'd45, "B inicia CALCULATE");
        key_cycle(1'b0, 4'd0, 6'b000010, dut.SHOW_RESULT, 6'b000001,
                  10'd12, 10'd45, "calculate dura un ciclo");
        key_cycle(1'b1, 4'd9, 6'b000001, dut.SHOW_RESULT, 6'b000001,
                  10'd12, 10'd45, "SHOW_RESULT ignora digitos");
        key_cycle(1'b1, 4'hC, 6'b000001, dut.SHOW_RESULT, 6'b000001,
                  10'd12, 10'd45, "SHOW_RESULT ignora C y conserva operandos");
        key_cycle(1'b0, 4'hD, 6'b000001, dut.SHOW_RESULT, 6'b000001,
                  10'd12, 10'd45, "D sin key_valid no cambia estado");
        key_cycle(1'b1, 4'hD, 6'b110000, dut.IDLE, 6'b110000,
                  10'd0, 10'd0, "D limpia desde SHOW_RESULT en el mismo flanco");
        key_cycle(1'b0, 4'd0, 6'b110000, dut.IDLE, 6'b110000,
                  10'd0, 10'd0, "siguiente flanco conserva ambos registros limpios");
        key_cycle(1'b1, 4'd0, 6'b011000, dut.INPUT_A, 6'b001000,
                  10'd0, 10'd0, "cero tambien es primer digito valido");

        @(negedge clk);
        reset = 1'b1;
        key_valid = 1'b1;
        key_code = 4'd7;
        #1ns;
        check_outputs(6'b110000, "reset inhibe la carga");
        check_registered(dut.INPUT_A, 10'd0, 10'd0,
                         "reset sincrono espera el flanco");
        @(posedge clk);
        #1ns;
        check_outputs(6'b110000, "salidas durante reset");
        check_registered(dut.IDLE, 10'd0, 10'd0,
                         "reset desde INPUT_A vuelve a IDLE");

        @(negedge clk);
        reset = 1'b0;
        key_valid = 1'b0;
        key_cycle(1'b1, 4'd1, 6'b011000, dut.INPUT_A, 6'b001000,
                  10'd1, 10'd0, "CALCULATE: preparar A=1");
        key_cycle(1'b1, 4'hA, 6'b000000, dut.INPUT_B, 6'b000000,
                  10'd1, 10'd0, "CALCULATE: seleccionar B");
        key_cycle(1'b1, 4'd2, 6'b000100, dut.INPUT_B, 6'b000100,
                  10'd1, 10'd2, "CALCULATE: preparar B=2");
        key_cycle(1'b1, 4'hB, 6'b000000, dut.CALCULATE, 6'b000010,
                  10'd1, 10'd2, "CALCULATE: iniciar calculo");
        key_cycle(1'b1, 4'hD, 6'b110000, dut.IDLE, 6'b110000,
                  10'd0, 10'd0, "D desde CALCULATE inhibe calculate y limpia");

        $display("Cantidad total de pruebas: %0d", total_tests);
        $display("Cantidad de errores: %0d", errors);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");
        $finish;
    end

endmodule

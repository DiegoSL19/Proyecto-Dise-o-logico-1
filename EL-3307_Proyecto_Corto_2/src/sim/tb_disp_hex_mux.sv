module tb_disp_hex_mux;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int unsigned TEST_N = 4;
    localparam int unsigned FRAME_CYCLES = 1 << TEST_N;

    logic clk;
    logic reset;
    logic [3:0] hex3;
    logic [3:0] hex2;
    logic [3:0] hex1;
    logic [3:0] hex0;
    logic [3:0] dp_in;
    logic [3:0] an;
    logic [7:0] sseg;
    logic [6:0] expected_patterns [0:3];
    int unsigned elapsed_cycles;
    int unsigned total_tests;
    int unsigned errors;

    disp_hex_mux #(
        .N(TEST_N)
    ) dut (
        .clk   (clk),
        .reset (reset),
        .hex3  (hex3),
        .hex2  (hex2),
        .hex1  (hex1),
        .hex0  (hex0),
        .dp_in (dp_in),
        .an    (an),
        .sseg  (sseg)
    );

    // Reloj de aproximadamente 27 MHz.
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

    // Comprobar exclusivamente las salidas externas del DUT.
    task automatic check_outputs (
        input int unsigned selected_digit,
        input string description
    );
        logic [3:0] expected_an;
        logic [7:0] expected_sseg;

        case (selected_digit)
            0: expected_an = 4'b1110;
            1: expected_an = 4'b1101;
            2: expected_an = 4'b1011;
            3: expected_an = 4'b0111;
            default: expected_an = 4'b1111;
        endcase
        expected_sseg = {dp_in[selected_digit], expected_patterns[selected_digit]};
        report(({an, sseg} === {expected_an, expected_sseg}),
               $sformatf("%s | digito=%0d an=%b segmentos=%b dp=%b",
                         description, selected_digit, expected_an,
                         expected_sseg[6:0], expected_sseg[7]));
    endtask

    task automatic check_cycles (
        input int unsigned cycles,
        input string description
    );
        int unsigned selected_digit;

        repeat (cycles) begin
            @(posedge clk);
            #1ns; // Esperar las asignaciones no bloqueantes y la combinacional.
            elapsed_cycles += 1;
            // N=4: cada digito ocupa cuatro ciclos; la secuencia se repite.
            selected_digit = (elapsed_cycles >> (TEST_N - 2)) & 3;
            check_outputs(selected_digit,
                          $sformatf("%s | ciclo=%0d", description, elapsed_cycles));
        end
    endtask

    task automatic load_and_check (
        input logic [3:0] next_hex3,
        input logic [3:0] next_hex2,
        input logic [3:0] next_hex1,
        input logic [3:0] next_hex0,
        input logic [6:0] pattern3,
        input logic [6:0] pattern2,
        input logic [6:0] pattern1,
        input logic [6:0] pattern0,
        input logic [3:0] next_dp,
        input string description
    );
        @(negedge clk);
        hex3 = next_hex3;
        hex2 = next_hex2;
        hex1 = next_hex1;
        hex0 = next_hex0;
        expected_patterns[3] = pattern3;
        expected_patterns[2] = pattern2;
        expected_patterns[1] = pattern1;
        expected_patterns[0] = pattern0;
        dp_in = next_dp;
        #1ns;
        check_outputs((elapsed_cycles >> (TEST_N - 2)) & 3,
                      {description, " | cambio combinacional"});
        check_cycles(FRAME_CYCLES, description);
    endtask

    initial begin
        reset = 1'b1;
        hex3 = 4'h4;
        hex2 = 4'h3;
        hex1 = 4'h2;
        hex0 = 4'h1;
        dp_in = 4'b1010;
        expected_patterns[3] = 7'b1001100;
        expected_patterns[2] = 7'b0000110;
        expected_patterns[1] = 7'b0010010;
        expected_patterns[0] = 7'b1001111;
        elapsed_cycles = 0;
        total_tests = 0;
        errors = 0;

        repeat (2) begin
            @(posedge clk);
            #1ns;
            check_outputs(0, "reset selecciona hex0=1");
        end

        @(negedge clk);
        reset = 1'b0;
        // Dos vueltas comprueban orden, permanencia y retorno de hex3 a hex0.
        check_cycles(2 * FRAME_CYCLES, "hex0=1 hex1=2 hex2=3 hex3=4; dp=1010");

        // Referencias explicitas tomadas de los patrones del curso.
        load_and_check(4'hA, 4'h9, 4'h5, 4'h0,
                       7'b0001000, 7'b0000100, 7'b0100100, 7'b0000001,
                       4'b1010, "patrones 0, 5, 9, A");
        load_and_check(4'hE, 4'hD, 4'hC, 4'hB,
                       7'b0110000, 7'b1000010, 7'b0110001, 7'b1100000,
                       4'b1010, "patrones B, C, D, E");
        load_and_check(4'h8, 4'h7, 4'h6, 4'hF,
                       7'b0000000, 7'b0001111, 7'b0100000, 7'b0111000,
                       4'b0101, "patrones F, 6, 7, 8; dp=0101");

        @(negedge clk);
        dp_in = 4'b0000;
        #1ns;
        check_outputs(0, "dp=0000: cambio combinacional");
        check_cycles(FRAME_CYCLES, "dp=0000: todos los puntos encendidos");
        @(negedge clk);
        dp_in = 4'b1111;
        #1ns;
        check_outputs(0, "dp=1111: cambio combinacional");
        check_cycles(FRAME_CYCLES, "dp=1111: todos los puntos apagados");

        // Aplicar reset mientras esta seleccionado hex1, no hex0.
        check_cycles(6, "avance antes del segundo reset");
        @(negedge clk);
        reset = 1'b1;
        #1ns;
        check_outputs(1, "reset sincronico no cambia antes del posedge");
        @(posedge clk);
        #1ns;
        elapsed_cycles = 0;
        check_outputs(0, "reset reinicia la seleccion en hex0");
        @(negedge clk);
        reset = 1'b0;
        check_cycles(FRAME_CYCLES, "secuencia reiniciada despues del reset");

        $display("Total de pruebas: %0d", total_tests);
        $display("Errores: %0d", errors);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");
        $finish;
    end

endmodule

module tb_vending_display;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int unsigned TEST_DISPLAY_DIV = 4;
    localparam int unsigned WAIT_LIMIT = 4 * TEST_DISPLAY_DIV + 4;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic enable = 1'b0;
    logic [9:0] value = 10'd0;
    logic [3:0] an_high;
    logic [7:0] sseg_high;
    logic [3:0] an_low;
    logic [7:0] sseg_low;
    logic manual_tick = 1'b0;
    logic [3:0] manual_an;
    logic [7:0] manual_sseg;
    int unsigned checks = 0;
    int unsigned errors = 0;

    vending_display #(.DISPLAY_DIV(TEST_DISPLAY_DIV)) dut_high (
        .clk(clk), .reset(reset), .value(value), .enable(enable),
        .an(an_high), .sseg(sseg_high)
    );

    vending_display #(
        .DISPLAY_DIV(TEST_DISPLAY_DIV),
        .SEGMENTS_ACTIVE_LOW(1'b1),
        .DIGITS_ACTIVE_LOW(1'b1)
    ) dut_low (
        .clk(clk), .reset(reset), .value(value), .enable(enable),
        .an(an_low), .sseg(sseg_low)
    );

    // Este mux permite verificar su entrada publica de habilitacion.
    disp_hex_mux #(.N(2), .USE_TICK(1'b1)) manual_mux (
        .clk(clk), .reset(reset), .tick(manual_tick),
        .hex3(4'd3), .hex2(4'd2), .hex1(4'd1), .hex0(4'd0),
        .dp_in(4'b1111), .an(manual_an), .sseg(manual_sseg)
    );

    always #18.518ns clk = ~clk;

    task automatic check(input logic passed, input string description);
        checks += 1;
        if (passed !== 1'b1) begin
            errors += 1;
            $error("FAIL: %s | value=%0d an=%b sseg=%b",
                   description, value, an_high, sseg_high);
            if (errors >= 20)
                $fatal(1, "Demasiados errores en tb_vending_display");
        end
    endtask

    // Referencia decimal independiente de la ROM usada por el circuito.
    function automatic logic [6:0] decimal_segments(input int unsigned digit);
        case (digit)
            0: decimal_segments = 7'b1111110;
            1: decimal_segments = 7'b0110000;
            2: decimal_segments = 7'b1101101;
            3: decimal_segments = 7'b1111001;
            4: decimal_segments = 7'b0110011;
            5: decimal_segments = 7'b1011011;
            6: decimal_segments = 7'b1011111;
            7: decimal_segments = 7'b1110000;
            8: decimal_segments = 7'b1111111;
            9: decimal_segments = 7'b1111011;
            default: decimal_segments = 7'b0000000;
        endcase
    endfunction

    task automatic check_blank;
        check(({an_high, sseg_high} === 12'b0000_00000000),
              "salidas activas altas completamente apagadas");
        check(({an_low, sseg_low} === 12'b1111_11111111),
              "salidas activas bajas completamente apagadas");
    endtask

    task automatic check_amount(input int unsigned amount);
        logic [3:0] seen;
        int unsigned cycles;
        int selected;
        int unsigned expected_digit;

        @(negedge clk);
        value = amount;
        enable = 1'b1;
        seen = 4'b0000;
        cycles = 0;

        while ((seen != 4'b1111) && (cycles < WAIT_LIMIT)) begin
            @(posedge clk);
            #1ns;
            cycles += 1;

            selected = -1;
            case (an_high)
                4'b0001: begin selected = 0; expected_digit = amount % 10; end
                4'b0010: begin selected = 1; expected_digit = (amount / 10) % 10; end
                4'b0100: begin selected = 2; expected_digit = (amount / 100) % 10; end
                4'b1000: begin selected = 3; expected_digit = amount / 1000; end
                default: expected_digit = 0;
            endcase

            check(selected >= 0, "exactamente un digito habilitado");
            check(({an_low, sseg_low} === ~{an_high, sseg_high}),
                  "ambas polaridades muestran el mismo contenido");
            check((sseg_high[7] === 1'b0) && (sseg_low[7] === 1'b1),
                  "puntos decimales apagados");
            if (selected >= 0) begin
                check(sseg_high[6:0] === decimal_segments(expected_digit),
                      $sformatf("decimal %04d, posicion %0d", amount, selected));
                seen[selected] = 1'b1;
            end
        end

        check(seen === 4'b1111,
              $sformatf("los cuatro digitos de %04d aparecen antes del limite", amount));
    endtask

    task automatic check_manual_mux;
        logic [3:0] expected_an;
        int unsigned selected;

        expected_an = 4'b1110;
        repeat (5) begin
            @(posedge clk);
            #1ns;
            check(manual_an === expected_an, "sin tick el selector conserva unidades");
            check(manual_sseg === 8'b1_0000001, "sin tick conserva segmentos de cero");
        end

        for (int unsigned step = 1; step <= 4; step += 1) begin
            @(negedge clk);
            manual_tick = 1'b1;
            @(posedge clk);
            #1ns;
            selected = step % 4;
            case (selected)
                0: expected_an = 4'b1110;
                1: expected_an = 4'b1101;
                2: expected_an = 4'b1011;
                3: expected_an = 4'b0111;
            endcase
            check(manual_an === expected_an, "un tick avanza un solo digito");
            check(manual_sseg === {1'b1, ~decimal_segments(selected)},
                  "el tick selecciona los segmentos del digito correcto");

            @(negedge clk);
            manual_tick = 1'b0;
            repeat (5) begin
                @(posedge clk);
                #1ns;
                check(manual_an === expected_an, "selector inmovil entre ticks");
                check(manual_sseg === {1'b1, ~decimal_segments(selected)},
                      "segmentos estables entre ticks");
            end
        end
    endtask

    initial begin
        #1ns;
        check_blank();
        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        check_manual_mux();

        // Incluye 0000, 0025, 0050, 0550, 0999, 1000 y 1023.
        for (int unsigned amount = 0; amount < 1024; amount += 1)
            check_amount(amount);

        @(negedge clk);
        enable = 1'b0;
        #1ns;
        check_blank();
        repeat (2 * WAIT_LIMIT) begin
            @(posedge clk);
            #1ns;
            check_blank();
        end

        // El reset debe apagar los cuatro digitos aun con enable activo.
        @(negedge clk);
        enable = 1'b1;
        reset = 1'b1;
        #1ns;
        check_blank();
        repeat (3) begin
            @(posedge clk);
            #1ns;
            check_blank();
            check(manual_an === 4'b1110, "reset reinicia el mux en unidades");
        end
        @(negedge clk);
        reset = 1'b0;
        check_amount(50);
        check_amount(25);
        check_amount(0);

        $display("RESULT: %0d tests, %0d errors", checks, errors);
        if (errors != 0)
            $fatal(1, "Fallo en tb_vending_display");
        $display("PASS: vending_display");
        $finish;
    end

    initial begin
        #5ms;
        $fatal(1, "Timeout en tb_vending_display");
    end
endmodule

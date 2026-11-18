module tb_vending_netlist;
    timeunit 1ns;
    timeprecision 1ps;

    parameter int unsigned SETTLE_CYCLES = 48;
    parameter int unsigned PRESS_CYCLES = 32;
    parameter int unsigned EXPECTED_REFUND_CYCLES = 256;
    parameter int unsigned WAIT_LIMIT = 2048;

    logic clk = 1'b0;
    logic reset_n = 1'b0;
    logic start_n = 1'b1;
    logic restart_n = 1'b1;
    logic [1:0] product_sw = 2'b11;
    logic [2:0] coins_sw = 3'b111;
    wire [2:0] delivery_led_n;
    wire [2:0] empty_led_n;
    wire refund_led;
    wire [3:0] an;
    wire [7:0] sseg;

    int unsigned checks = 0;
    int unsigned errors = 0;
    int unsigned deliveries = 0;
    int unsigned refunds = 0;
    int unsigned refund_width = 0;
    int unsigned last_refund_width = 0;
    logic [2:0] previous_delivery = 3'b000;
    logic previous_refund = 1'b0;

    // El DUT es la netlist generada, sin parametros ni referencias internas.
    vending_verify_top uut (
        .clk(clk), .reset_n(reset_n), .restart_n(restart_n), .start_n(start_n),
        .product_sw(product_sw), .coins_sw(coins_sw),
        .delivery_led_n(delivery_led_n), .empty_led_n(empty_led_n),
        .refund_led(refund_led), .an(an), .sseg(sseg)
    );

    always #18.518518ns clk = ~clk;

    // Se observa despues del flanco opuesto para permitir los retardos SDF.
    always @(negedge clk) begin
        #1ns;
        if (!reset_n) begin
            previous_delivery = 3'b000;
            previous_refund = 1'b0;
            refund_width = 0;
        end else begin
            if ((delivery_led_n != 3'b111) && (previous_delivery == 3'b000))
                deliveries += 1;
            previous_delivery = ~delivery_led_n;
            if (refund_led === 1'b1)
                refund_width += 1;
            else if (previous_refund) begin
                refunds += 1;
                last_refund_width = refund_width;
                refund_width = 0;
            end
            previous_refund = refund_led;
        end
    end

    task automatic check(input logic passed, input string description);
        checks += 1;
        if (passed !== 1'b1) begin
            errors += 1;
            $error("FAIL: %s | entrega=%b agotado=%b refund=%b an=%b sseg=%b",
                   description, delivery_led_n, empty_led_n, refund_led, an, sseg);
            if (errors >= 10)
                $fatal(1, "Demasiados errores de netlist");
        end
    endtask

    task automatic cycles(input int unsigned count);
        repeat (count) begin
            @(negedge clk);
            #2ns;
        end
    endtask

    task automatic blank;
        check(({an, sseg} === 12'd0), "display completamente apagado");
    endtask

    function automatic logic [6:0] segments(input int unsigned digit);
        case (digit)
            0: segments = 7'b1111110;
            1: segments = 7'b0110000;
            2: segments = 7'b1101101;
            3: segments = 7'b1111001;
            4: segments = 7'b0110011;
            5: segments = 7'b1011011;
            6: segments = 7'b1011111;
            7: segments = 7'b1110000;
            8: segments = 7'b1111111;
            9: segments = 7'b1111011;
            default: segments = 7'd0;
        endcase
    endfunction

    task automatic display_amount(input int unsigned amount);
        logic [3:0] seen;
        int selected;
        int unsigned digit;
        int unsigned elapsed;

        seen = 4'b0000;
        elapsed = 0;
        while ((seen != 4'b1111) && (elapsed < 64)) begin
            cycles(1);
            elapsed += 1;
            selected = -1;
            case (an)
                4'b0001: begin selected = 0; digit = amount % 10; end
                4'b0010: begin selected = 1; digit = (amount / 10) % 10; end
                4'b0100: begin selected = 2; digit = (amount / 100) % 10; end
                4'b1000: begin selected = 3; digit = amount / 1000; end
                default: digit = 0;
            endcase
            check(selected >= 0, "un solo digito habilitado");
            check(sseg[7] === 1'b0, "punto decimal apagado");
            if (selected >= 0) begin
                check(sseg[6:0] === segments(digit),
                      $sformatf("vuelto %04d, posicion %0d", amount, selected));
                seen[selected] = 1'b1;
            end
        end
        check(seen === 4'b1111, "se observaron los cuatro digitos del vuelto");
    endtask

    task automatic select_inputs(input logic [1:0] product,
                                 input logic [2:0] coins);
        @(negedge clk);
        product_sw = ~product;
        coins_sw = ~coins;
        cycles(SETTLE_CYCLES);
    endtask

    task automatic start;
        @(negedge clk);
        start_n = 1'b0;
        cycles(PRESS_CYCLES);
        @(negedge clk);
        start_n = 1'b1;
        cycles(PRESS_CYCLES);
    endtask

    task automatic restart;
        @(negedge clk);
        restart_n = 1'b0;
        cycles(PRESS_CYCLES);
        @(negedge clk);
        restart_n = 1'b1;
        cycles(PRESS_CYCLES);
        check(delivery_led_n === 3'b111, "RESTART apaga la entrega");
        blank();
    endtask

    task automatic buy(input logic [1:0] product, input logic [2:0] coins,
                       input int unsigned change, input logic [2:0] expected_empty_n);
        logic [2:0] expected_delivery;
        int unsigned before_delivery;
        int unsigned elapsed;

        before_delivery = deliveries;
        expected_delivery = ~(3'b001 << product);
        select_inputs(product, coins);
        start();
        elapsed = 0;
        while ((delivery_led_n !== expected_delivery) && (elapsed < WAIT_LIMIT)) begin
            cycles(1);
            elapsed += 1;
        end
        check(delivery_led_n === expected_delivery, "entrega del producto solicitado");
        check(deliveries == before_delivery + 1, "una sola entrega por pulsacion");
        check(empty_led_n === expected_empty_n, "inventario y agotamiento correctos");
        check(refund_led === 1'b0, "compra aprobada sin devolucion");
        display_amount(change);
        cycles(24);
        check(delivery_led_n === expected_delivery, "entrega visible hasta RESTART");
        display_amount(change);
    endtask

    task automatic reject(input logic [1:0] product, input logic [2:0] coins,
                          input logic [2:0] expected_empty_n);
        int unsigned before_delivery;
        int unsigned before_refund;
        int unsigned elapsed;

        before_delivery = deliveries;
        before_refund = refunds;
        select_inputs(product, coins);
        start();
        elapsed = 0;
        while ((refund_led !== 1'b1) && (elapsed < WAIT_LIMIT)) begin
            cycles(1);
            elapsed += 1;
        end
        check(refund_led === 1'b1, "rechazo activa devolucion");
        blank();
        elapsed = 0;
        while ((refunds == before_refund) && (elapsed < WAIT_LIMIT)) begin
            cycles(1);
            elapsed += 1;
        end
        check(refunds == before_refund + 1, "devolucion completa y terminada");
        check(last_refund_width == EXPECTED_REFUND_CYCLES,
              "duracion completa del indicador de devolucion");
        check(deliveries == before_delivery, "rechazo sin entregar producto");
        check(delivery_led_n === 3'b111, "rechazo no enciende entrega");
        check(empty_led_n === expected_empty_n, "rechazo conserva inventario");
        blank();
    endtask

    initial begin
        cycles(32);
        check(delivery_led_n === 3'b111, "reset sin entregas");
        check(empty_led_n === 3'b111, "reset repone inventario");
        blank();
        @(negedge clk);
        reset_n = 1'b1;
        cycles(SETTLE_CYCLES);

        buy(2'd0, 3'd2, 50, 3'b111);
        restart();
        buy(2'd1, 3'd3, 25, 3'b111);
        restart();
        buy(2'd2, 3'd4, 0, 3'b111);
        restart();
        reject(2'd2, 3'd3, 3'b111);

        // Dos entregas mas de C prueban que el rechazo no consumio existencias.
        buy(2'd2, 3'd4, 0, 3'b111);
        restart();
        buy(2'd2, 3'd4, 0, 3'b011);
        restart();

        // A ya fue comprado una vez: dos entregas mas deben agotarlo.
        buy(2'd0, 3'd2, 50, 3'b011);
        restart();
        buy(2'd0, 3'd2, 50, 3'b010);
        restart();
        reject(2'd0, 3'd2, 3'b010);

        @(negedge clk);
        reset_n = 1'b0;
        cycles(32);
        check(empty_led_n === 3'b111, "reset global recupera productos agotados");
        blank();
        @(negedge clk);
        reset_n = 1'b1;
        cycles(SETTLE_CYCLES);
        buy(2'd0, 3'd2, 50, 3'b111);

        restart();
        buy(2'd0, 3'd7, 550, 3'b111);

        $display("RESULT: %0d tests, %0d errors", checks, errors);
        $display("NETLIST_ACTIONS: %0d deliveries, %0d refunds", deliveries, refunds);
        if (errors != 0)
            $fatal(1, "Fallo de simulacion de netlist");
        $display("PASS: vending_netlist");
        $finish;
    end

    initial begin
        #2ms;
        $fatal(1, "Timeout de simulacion de netlist");
    end
endmodule

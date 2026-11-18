module tb_vending_top;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int unsigned TEST_DEBOUNCE_N = 4;
    localparam logic [25:0] TEST_REFUND_CYCLES = 26'd256;
    localparam int unsigned TEST_DISPLAY_DIV = 3;
    localparam int unsigned SETTLE_CYCLES = 40;
    localparam int unsigned TIMEOUT_CYCLES = 1024;

    logic clk = 1'b0;
    logic reset_n = 1'b0;
    logic restart_n = 1'b1;
    logic start_n = 1'b1;
    logic [1:0] product_sw = 2'b11;
    logic [2:0] coins_sw = 3'b111;
    logic [2:0] delivery_led_n;
    logic [2:0] empty_led_n;
    logic refund_led;
    logic [3:0] an;
    logic [7:0] sseg;
    logic short_reset_n = 1'b0;
    logic short_start_n = 1'b1;
    logic short_refund_led;
    logic previous_short_refund = 1'b0;
    int unsigned short_refund_width = 0;
    int unsigned short_refunds_completed = 0;

    int unsigned checks = 0;
    int unsigned errors = 0;
    int unsigned requests = 0;
    int unsigned starts = 0;
    int unsigned restarts = 0;
    int unsigned deliveries = 0;
    int unsigned refunds = 0;
    int unsigned refund_width = 0;
    int unsigned last_refund_width = 0;
    logic [9:0] last_refund_credit = 10'd0;
    logic previous_request = 1'b0;
    logic previous_start = 1'b0;
    logic previous_restart = 1'b0;
    logic [2:0] previous_decrement = 3'b000;
    logic previous_refund_led = 1'b0;
    logic transaction_observed = 1'b0;
    logic [1:0] observed_product = 2'b00;
    logic [9:0] observed_credit = 10'd0;

    vending_top #(
        .DEBOUNCE_N(TEST_DEBOUNCE_N),
        .REFUND_CYCLES(TEST_REFUND_CYCLES),
        .DISPLAY_DIV(TEST_DISPLAY_DIV)
    ) dut (
        .clk(clk),
        .reset_n(reset_n),
        .restart_n(restart_n),
        .start_n(start_n),
        .product_sw(product_sw),
        .coins_sw(coins_sw),
        .delivery_led_n(delivery_led_n),
        .empty_led_n(empty_led_n),
        .refund_led(refund_led),
        .an(an),
        .sseg(sseg)
    );

    // Limite minimo del temporizador: una devolucion visible durante un ciclo.
    vending_top #(
        .DEBOUNCE_N(TEST_DEBOUNCE_N),
        .REFUND_CYCLES(26'd1),
        .DISPLAY_DIV(TEST_DISPLAY_DIV)
    ) short_dut (
        .clk(clk),
        .reset_n(short_reset_n),
        .restart_n(1'b1),
        .start_n(short_start_n),
        .product_sw(2'b11),
        .coins_sw(3'b110),
        .delivery_led_n(),
        .empty_led_n(),
        .refund_led(short_refund_led),
        .an(),
        .sseg()
    );

    // Periodo aproximado de 37.036 ns: reloj unico de 27 MHz.
    always #18.518ns clk = ~clk;

    task automatic check(input logic passed, input string description);
        checks += 1;
        if (passed !== 1'b1) begin
            errors += 1;
            $error("FAIL: %s", description);
        end
    endtask

    task automatic cycles(input int unsigned count);
        repeat (count) begin
            @(posedge clk);
            #1ns; // Observar las asignaciones no bloqueantes ya actualizadas.
        end
    endtask

    // Referencia decimal independiente de la ROM del circuito.
    function automatic logic [15:0] decimal_digits(input int unsigned amount);
        decimal_digits[15:12] = amount / 1000;
        decimal_digits[11:8] = (amount / 100) % 10;
        decimal_digits[7:4] = (amount / 10) % 10;
        decimal_digits[3:0] = amount % 10;
    endfunction

    function automatic logic [7:0] decimal_segments(input logic [3:0] digit);
        case (digit)
            4'd0: decimal_segments = 8'b01111110;
            4'd1: decimal_segments = 8'b00110000;
            4'd2: decimal_segments = 8'b01101101;
            4'd3: decimal_segments = 8'b01111001;
            4'd4: decimal_segments = 8'b00110011;
            4'd5: decimal_segments = 8'b01011011;
            4'd6: decimal_segments = 8'b01011111;
            4'd7: decimal_segments = 8'b01110000;
            4'd8: decimal_segments = 8'b01111111;
            4'd9: decimal_segments = 8'b01111011;
            default: decimal_segments = 8'b00000000;
        endcase
    endfunction

    task automatic check_display(input logic [15:0] expected);
        logic [3:0] seen;
        int unsigned elapsed;
        seen = 4'b0000;
        elapsed = 0;
        while ((seen != 4'b1111) && (elapsed < TIMEOUT_CYCLES)) begin
            cycles(1);
            elapsed += 1;
            case (an)
                4'b0001: if (!seen[0]) begin
                    check(sseg === decimal_segments(expected[3:0]), "display: unidades correctas");
                    seen[0] = 1'b1;
                end
                4'b0010: if (!seen[1]) begin
                    check(sseg === decimal_segments(expected[7:4]), "display: decenas correctas");
                    seen[1] = 1'b1;
                end
                4'b0100: if (!seen[2]) begin
                    check(sseg === decimal_segments(expected[11:8]), "display: centenas correctas");
                    seen[2] = 1'b1;
                end
                4'b1000: if (!seen[3]) begin
                    check(sseg === decimal_segments(expected[15:12]), "display: millares correctos");
                    seen[3] = 1'b1;
                end
                default: check(1'b0, "display: un solo digito activo durante entrega");
            endcase
        end
        check(seen == 4'b1111, "display recorre los cuatro digitos");
    endtask

    task automatic check_display_blank;
        check(an === 4'b0000, "display sin digitos habilitados fuera de la entrega");
        check(sseg === 8'b00000000, "segmentos y puntos apagados fuera de la entrega");
    endtask

    task automatic wait_inputs_ready;
        int unsigned elapsed;
        elapsed = 0;
        while (((dut.inputs_ready !== 1'b1) ||
                (dut.dips_ready !== 1'b1)) &&
               (elapsed < TIMEOUT_CYCLES)) begin
            cycles(1);
            elapsed += 1;
        end
        if (elapsed == TIMEOUT_CYCLES)
            $fatal(1, "Timeout esperando entradas estables");
        cycles(2);
    endtask

    task automatic wait_refund_finished;
        int unsigned elapsed;
        elapsed = 0;
        while ((refund_led !== 1'b0) &&
               (elapsed < TIMEOUT_CYCLES)) begin
            cycles(1);
            elapsed += 1;
        end
        if (elapsed == TIMEOUT_CYCLES)
            $fatal(1, "Timeout esperando fin del LED de devolucion");
        cycles(2);
    endtask

    task automatic set_switches(
        input logic [1:0] product,
        input logic [2:0] coin_count
    );
        @(negedge clk);
        // Contacto cerrado a GND = bit logico 1, por tanto DIP activos bajos.
        product_sw = ~product;
        coins_sw = ~coin_count;
        cycles(SETTLE_CYCLES);
        wait_inputs_ready();
    endtask

    task automatic press_start;
        @(negedge clk);
        start_n = 1'b0;
        cycles(SETTLE_CYCLES);
    endtask

    task automatic release_start;
        @(negedge clk);
        start_n = 1'b1;
        cycles(SETTLE_CYCLES);
    endtask

    task automatic press_start_with_bounce(input logic wait_after_press = 1'b1);
        @(negedge clk);
        start_n = 1'b0;
        cycles(2);
        @(negedge clk);
        start_n = 1'b1;
        cycles(2);
        @(negedge clk);
        start_n = 1'b0;
        cycles(2);
        @(negedge clk);
        start_n = 1'b1;
        cycles(2);
        @(negedge clk);
        start_n = 1'b0;
        if (wait_after_press)
            cycles(SETTLE_CYCLES);
    endtask

    task automatic release_start_with_bounce;
        @(negedge clk);
        start_n = 1'b1;
        cycles(2);
        @(negedge clk);
        start_n = 1'b0;
        cycles(2);
        @(negedge clk);
        start_n = 1'b1;
        cycles(2);
        @(negedge clk);
        start_n = 1'b0;
        cycles(2);
        @(negedge clk);
        start_n = 1'b1;
        cycles(SETTLE_CYCLES);
    endtask

    task automatic apply_reset(
        input logic hold_start,
        input logic hold_restart
    );
        int unsigned saved_requests;
        int unsigned saved_starts;
        int unsigned saved_restarts;
        saved_requests = requests;
        saved_starts = starts;
        saved_restarts = restarts;
        @(negedge clk);
        reset_n = 1'b0;
        start_n = ~hold_start;
        restart_n = ~hold_restart;
        cycles(4);
        check(delivery_led_n === 3'b111, "reset apaga los LED de entrega");
        check(empty_led_n === 3'b111, "reset apaga los LED de agotado");
        check(refund_led === 1'b0, "reset apaga el LED de devolucion");
        check_display_blank();
        check({dut.inventory_A, dut.inventory_B, dut.inventory_C} ===
              {2'd3, 2'd3, 2'd3}, "reset restaura inventarios 3/3/3");
        @(negedge clk);
        reset_n = 1'b1;
        cycles(SETTLE_CYCLES);
        wait_inputs_ready();
        check(requests == saved_requests, "reset no crea solicitudes");
        check(starts == saved_starts, "START sostenido al salir de reset no crea evento");
        check(restarts == saved_restarts, "RESTART sostenido al salir de reset no crea evento");
        @(negedge clk);
        start_n = 1'b1;
        restart_n = 1'b1;
        cycles(SETTLE_CYCLES);
        check(requests == saved_requests, "soltar tras reset no crea solicitud");
        check(starts == saved_starts, "soltar START tras reset no crea evento");
        check(restarts == saved_restarts, "soltar RESTART tras reset no crea evento");
    endtask

    task automatic restart_purchase(input logic simultaneous_start = 1'b0);
        logic [5:0] saved_inventory;
        int unsigned saved_restarts;
        int unsigned saved_deliveries;
        int unsigned saved_requests;
        int unsigned saved_starts;
        saved_inventory = {dut.inventory_A, dut.inventory_B, dut.inventory_C};
        saved_restarts = restarts;
        saved_deliveries = deliveries;
        saved_requests = requests;
        saved_starts = starts;
        @(negedge clk);
        restart_n = 1'b0;
        if (simultaneous_start)
            start_n = 1'b0;
        cycles(SETTLE_CYCLES);
        check(restarts == saved_restarts + 1, "RESTART produce un evento");
        check(dut.transaction_busy === 1'b0, "RESTART aceptado libera la transaccion");
        check(delivery_led_n === 3'b111, "RESTART aceptado apaga entrega");
        check(dut.change_reg === 10'd0, "RESTART limpia el vuelto");
        check_display_blank();
        check({dut.inventory_A, dut.inventory_B, dut.inventory_C} === saved_inventory,
              "RESTART conserva el inventario");
        check(deliveries == saved_deliveries, "RESTART no entrega otro producto");
        check(requests == saved_requests, "START simultaneo con RESTART en espera no se acepta");
        if (simultaneous_start)
            check(starts == saved_starts + 1, "START simultaneo fue una pulsacion valida descartada por busy");
        cycles(SETTLE_CYCLES);
        check(restarts == saved_restarts + 1, "RESTART sostenido no repite evento");
        check(requests == saved_requests, "START simultaneo no se encola al volver a reposo");
        @(negedge clk);
        restart_n = 1'b1;
        start_n = 1'b1;
        cycles(SETTLE_CYCLES);
        check(restarts == saved_restarts + 1, "soltar RESTART no genera evento");
    endtask

    task automatic buy_product(
        input logic [1:0] product,
        input logic [2:0] coin_count,
        input logic [9:0] expected_change,
        input logic simultaneous_restart = 1'b0
    );
        logic [1:0] expected_A;
        logic [1:0] expected_B;
        logic [1:0] expected_C;
        logic [2:0] expected_delivery;
        int unsigned saved_requests;
        int unsigned saved_starts;
        int unsigned saved_deliveries;
        int unsigned saved_restarts;
        set_switches(product, coin_count);
        expected_A = dut.inventory_A;
        expected_B = dut.inventory_B;
        expected_C = dut.inventory_C;
        expected_delivery = 3'b000;
        case (product)
            2'b00: begin expected_A -= 2'd1; expected_delivery = 3'b001; end
            2'b01: begin expected_B -= 2'd1; expected_delivery = 3'b010; end
            2'b10: begin expected_C -= 2'd1; expected_delivery = 3'b100; end
            default: $fatal(1, "Producto invalido en buy_product");
        endcase
        saved_requests = requests;
        saved_starts = starts;
        saved_deliveries = deliveries;
        saved_restarts = restarts;
        if (simultaneous_restart) begin
            @(negedge clk);
            start_n = 1'b0;
            restart_n = 1'b0;
            cycles(SETTLE_CYCLES);
            check(restarts == saved_restarts + 1, "RESTART simultaneo en reposo genera su evento");
        end else begin
            press_start();
        end
        check(starts == saved_starts + 1, "una pulsacion START produce un evento");
        check(requests == saved_requests + 1, "una compra produce una solicitud");
        check(deliveries == saved_deliveries + 1, "una compra produce un decremento");
        check(dut.product_held === product, "producto retenido corresponde al DIP logico");
        check(dut.credit_held == (coin_count * 100), "credito retenido convierte monedas a colones");
        check(dut.change_reg === expected_change, "vuelto correcto para la compra");
        check_display(decimal_digits(expected_change));
        check(delivery_led_n === ~expected_delivery, "LED de entrega activo bajo del producto correcto");
        check(refund_led === 1'b0, "compra autorizada no indica devolucion");
        check(dut.transaction_busy === 1'b1, "compra espera RESTART");
        check({dut.inventory_A, dut.inventory_B, dut.inventory_C} ===
              {expected_A, expected_B, expected_C}, "solo se consume una unidad del producto elegido");
        cycles(SETTLE_CYCLES);
        check(starts == saved_starts + 1, "START sostenido no repite evento");
        check(requests == saved_requests + 1, "START sostenido no repite solicitud");
        check(deliveries == saved_deliveries + 1, "LED persistente no repite decremento");
        check(delivery_led_n === ~expected_delivery, "entrega permanece visible hasta RESTART");
        release_start();
        check(starts == saved_starts + 1, "liberar START no produce evento");
        if (simultaneous_restart) begin
            @(negedge clk);
            restart_n = 1'b1;
            cycles(SETTLE_CYCLES);
            check(dut.transaction_busy === 1'b1, "RESTART simultaneo en reposo no queda encolado");
        end
    endtask

    task automatic request_refund(
        input logic [1:0] product,
        input logic [2:0] coin_count
    );
        logic [5:0] saved_inventory;
        int unsigned saved_requests;
        int unsigned saved_starts;
        int unsigned saved_deliveries;
        int unsigned saved_refunds;
        set_switches(product, coin_count);
        saved_inventory = {dut.inventory_A, dut.inventory_B, dut.inventory_C};
        saved_requests = requests;
        saved_starts = starts;
        saved_deliveries = deliveries;
        saved_refunds = refunds;
        press_start();
        check(requests == saved_requests + 1, "rechazo procesa una solicitud");
        check(refunds == saved_refunds + 1, "rechazo genera una devolucion");
        check(last_refund_credit == (coin_count * 100), "devolucion conserva el credito completo, no el faltante");
        check(deliveries == saved_deliveries, "devolucion no decrementa inventario");
        check({dut.inventory_A, dut.inventory_B, dut.inventory_C} === saved_inventory,
              "devolucion conserva todos los inventarios");
        check(delivery_led_n === 3'b111, "devolucion no enciende entrega");
        check(refund_led === 1'b1, "LED de devolucion persiste despues de limpiar el core");
        check(dut.transaction_busy === 1'b0, "core vuelve a reposo tras devolver");
        check(dut.change_reg === 10'd0, "faltante no se guarda como vuelto");
        check_display_blank();
        wait_refund_finished();
        cycles(SETTLE_CYCLES);
        check(starts == saved_starts + 1, "START sostenido durante devolucion solo genera un evento");
        check(requests == saved_requests + 1, "START sostenido no reintenta al terminar devolucion");
        check(refunds == saved_refunds + 1, "devolucion no se repite al terminar su temporizador");
        release_start();
    endtask

    // Contar acciones en el flanco en que las consume el sistema.
    always @(posedge clk) begin
        if (dut.reset) begin
            previous_request = 1'b0;
            previous_start = 1'b0;
            previous_restart = 1'b0;
            previous_decrement = 3'b000;
            transaction_observed = 1'b0;
        end else begin
            if (dut.request_event) begin
                requests += 1;
                check(!previous_request, "request_event dura un ciclo");
                check(!refund_led, "no se acepta solicitud durante LED de devolucion");
                observed_product = dut.product_held;
                observed_credit = dut.credit_held;
                transaction_observed = 1'b1;
            end
            if (dut.start_event) begin
                starts += 1;
                check(!previous_start, "start_event dura un ciclo");
            end
            if (dut.restart_event) begin
                restarts += 1;
                check(!previous_restart, "restart_event dura un ciclo");
            end
            if ({dut.decrement_C, dut.decrement_B, dut.decrement_A} != 3'b000) begin
                deliveries += 1;
                check(previous_decrement == 3'b000, "decremento dura un ciclo");
                check(({dut.decrement_C, dut.decrement_B, dut.decrement_A} == 3'b001) ||
                      ({dut.decrement_C, dut.decrement_B, dut.decrement_A} == 3'b010) ||
                      ({dut.decrement_C, dut.decrement_B, dut.decrement_A} == 3'b100),
                      "solo un producto se decrementa por ciclo");
            end
            if (dut.refund_active) begin
                refunds += 1;
                last_refund_credit = dut.system_inst.credit_captured;
            end
            if (transaction_observed) begin
                // Invariantes continuos: no inflar el total por cada ciclo de espera.
                if (dut.product_held !== observed_product)
                    check(1'b0, "producto cambio mientras el core lo usa");
                if (dut.credit_held !== observed_credit)
                    check(1'b0, "credito cambio mientras el core lo usa");
                if (dut.clear_transaction)
                    transaction_observed = 1'b0;
            end
            previous_request = dut.request_event;
            previous_start = dut.start_event;
            previous_restart = dut.restart_event;
            previous_decrement = {dut.decrement_C, dut.decrement_B, dut.decrement_A};
        end
    end

    // La salida se apaga con done: el intervalo debe ser exactamente el parametro.
    always @(posedge clk) begin
        #1ns;
        if (dut.reset) begin
            previous_refund_led = 1'b0;
            refund_width = 0;
        end else begin
            if (refund_led)
                refund_width = previous_refund_led ? refund_width + 1 : 1;
            else if (previous_refund_led) begin
                last_refund_width = refund_width;
                check(refund_width == TEST_REFUND_CYCLES,
                      "LED de devolucion cumple intervalo y termina sin prolongarse");
            end
            previous_refund_led = refund_led;
        end
    end

    always @(posedge clk) begin
        #1ns;
        if (short_dut.reset) begin
            previous_short_refund = 1'b0;
            short_refund_width = 0;
        end else begin
            if (short_refund_led)
                short_refund_width = previous_short_refund ? short_refund_width + 1 : 1;
            else if (previous_short_refund) begin
                short_refunds_completed += 1;
                check(short_refund_width == 1, "REFUND_CYCLES=1 produce exactamente un ciclo visible");
            end
            previous_short_refund = short_refund_led;
        end
    end

    initial begin : scenarios
        int unsigned saved_requests;
        int unsigned saved_starts;
        int unsigned saved_deliveries;
        int unsigned saved_refunds;
        int unsigned elapsed;
        int unsigned saved_short_refunds;
        logic [5:0] saved_inventory;

        apply_reset(1'b0, 1'b0);

        // Un codigo invalido no debe introducir al core en su espera sin salida.
        set_switches(2'b11, 3'd3);
        saved_requests = requests;
        press_start();
        check(requests == saved_requests, "codigo 11 no llega al core");
        check(dut.transaction_busy === 1'b0, "codigo 11 no bloquea el wrapper");
        check(delivery_led_n === 3'b111, "codigo 11 no entrega producto");
        release_start();

        // Rebote y retencion del snapshot frente a cambios de DIP durante busy.
        set_switches(2'b00, 3'd2);
        saved_requests = requests;
        saved_starts = starts;
        saved_deliveries = deliveries;
        press_start_with_bounce(1'b0);
        elapsed = 0;
        while ((dut.system_inst.capture_credit !== 1'b1) &&
               (elapsed < TIMEOUT_CYCLES)) begin
            cycles(1);
            elapsed += 1;
        end
        if (elapsed == TIMEOUT_CYCLES)
            $fatal(1, "Timeout esperando captura del credito de la solicitud");
        cycles(1);
        check(dut.system_inst.credit_captured === 10'd200,
              "credito nuevo esta capturado antes de cargar producto");
        @(negedge clk);
        // Cambiar DIP entre los flancos de captura de credito y producto del core.
        product_sw = ~2'b01;
        coins_sw = ~3'd7;
        cycles(1);
        check(dut.system_inst.product_sel_reg === 2'b00,
              "captura de producto conserva A cuando DIP cambia entre capturas");
        cycles(SETTLE_CYCLES);
        check(starts == saved_starts + 1, "rebote al presionar solo crea un evento");
        check(requests == saved_requests + 1, "rebote al presionar solo crea una solicitud");
        check(dut.change_reg === 10'd50, "A con 200 entrega vuelto 50");
        check_display(16'h0050);
        check(delivery_led_n === 3'b110, "entrega A activa el bit 0 en bajo");
        check(dut.product_held === 2'b00, "cambiar DIP ocupado conserva producto A");
        check(dut.credit_held === 10'd200, "cambiar DIP ocupado conserva credito 200");
        check(dut.change_reg === 10'd50, "cambiar DIP ocupado conserva vuelto 50");
        check_display(16'h0050);
        check(deliveries == saved_deliveries + 1, "START mantenido con DIP nuevos no vuelve a entregar");
        release_start_with_bounce();
        check(starts == saved_starts + 1, "rebote de liberacion no crea evento START");
        restart_purchase(1'b1);

        buy_product(2'b01, 3'd3, 10'd25);
        restart_purchase();
        buy_product(2'b10, 3'd4, 10'd0, 1'b1);
        restart_purchase();
        request_refund(2'b10, 3'd3);

        // Una pulsacion NUEVA durante el LED se descarta, sin encolarla.
        set_switches(2'b00, 3'd1);
        saved_requests = requests;
        saved_refunds = refunds;
        press_start();
        release_start();
        check(refund_led === 1'b1, "devolucion sigue visible antes de segundo START");
        press_start();
        check(requests == saved_requests + 1, "START nuevo durante devolucion se descarta");
        wait_refund_finished();
        cycles(SETTLE_CYCLES);
        check(requests == saved_requests + 1, "START descartado no queda encolado");
        check(refunds == saved_refunds + 1, "timer rearmado no repite devolucion");
        release_start();

        // Tres ventas de A agotan stock; el cuarto intento devuelve todo.
        apply_reset(1'b0, 1'b0);
        repeat (3) begin
            buy_product(2'b00, 3'd2, 10'd50);
            restart_purchase();
        end
        check(dut.inventory_A === 2'd0, "tres compras agotan A");
        check(empty_led_n === 3'b110, "agotado A se indica en bit 0 activo bajo");
        request_refund(2'b00, 3'd2);
        check(empty_led_n === 3'b110, "devolucion y reinicio de transaccion conservan agotado A");

        // Un boton sostenido a traves del reset no crea pulsaciones falsas.
        apply_reset(1'b1, 1'b1);
        buy_product(2'b10, 3'd4, 10'd0);
        restart_purchase();

        // Verificar conversion para las ocho combinaciones de monedas.
        for (int unsigned coin_count = 0; coin_count < 8; coin_count += 1) begin
            apply_reset(1'b0, 1'b0);
            if (coin_count < 4) begin
                request_refund(2'b10, coin_count[2:0]);
                check(dut.credit_held == coin_count * 100,
                      "conversion 0..7 retiene credito aun despues de devolver");
            end else begin
                buy_product(2'b10, coin_count[2:0], (coin_count * 100) - 400);
                restart_purchase();
            end
        end

        // RESTART fuera de la espera final no borra existencias ni compra.
        saved_inventory = {dut.inventory_A, dut.inventory_B, dut.inventory_C};
        saved_requests = requests;
        @(negedge clk);
        restart_n = 1'b0;
        cycles(SETTLE_CYCLES);
        @(negedge clk);
        restart_n = 1'b1;
        cycles(SETTLE_CYCLES);
        check({dut.inventory_A, dut.inventory_B, dut.inventory_C} === saved_inventory,
              "RESTART en reposo conserva inventarios");
        check(requests == saved_requests, "RESTART en reposo no inicia compra");

        apply_reset(1'b0, 1'b0);
        check(empty_led_n === 3'b111, "reset final elimina agotamiento");
        check(refund_led === 1'b0, "reset final deja devolucion apagada");
        check(last_refund_width >= TEST_REFUND_CYCLES, "se comprobo temporizacion de devolucion");

        // Comprobar limite de un ciclo y su rearme para una segunda devolucion.
        @(negedge clk);
        short_reset_n = 1'b1;
        cycles(SETTLE_CYCLES);
        repeat (2) begin
            saved_short_refunds = short_refunds_completed;
            @(negedge clk);
            short_start_n = 1'b0;
            cycles(SETTLE_CYCLES);
            check(short_refunds_completed == saved_short_refunds + 1,
                  "temporizador de un ciclo se rearma en cada solicitud");
            check(short_refund_led === 1'b0, "devolucion de un ciclo termina");
            check(short_dut.inventory_A === 2'd3, "rechazo con timer de un ciclo conserva inventario");
            @(negedge clk);
            short_start_n = 1'b1;
            cycles(SETTLE_CYCLES);
        end
        // Pago maximo: el vuelto 550 utiliza la correccion de centenas de la ROM.
        apply_reset(1'b0, 1'b0);
        buy_product(2'b00, 3'd7, 10'd550);
        check_display(16'h0550);
        restart_purchase();

        $display("RESULT: %0d tests, %0d errors", checks, errors);
        $display("Actions: %0d requests, %0d deliveries, %0d refunds",
                 requests, deliveries, refunds);
        if (errors != 0)
            $fatal(1, "vending_top testbench failed");
        $display("PASS: vending_top");
        $finish;
    end

    initial begin
        #2ms;
        $fatal(1, "Timeout global en tb_vending_top");
    end
endmodule

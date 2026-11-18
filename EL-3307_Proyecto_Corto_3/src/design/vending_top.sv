module vending_top #(
    // N entre 1 y 32; el valor de hardware es 21.
    parameter int unsigned DEBOUNCE_N = 21,
    parameter logic [25:0] REFUND_CYCLES = 26'd54_000_000,
    parameter int unsigned DISPLAY_DIV = 6_750,
    // Interfaz fisica del Proyecto 2: segmentos y selectores activos altos.
    parameter logic SEGMENTS_ACTIVE_LOW = 1'b0,
    parameter logic DIGITS_ACTIVE_LOW = 1'b0
) (
    input  logic       clk,
    input  logic       reset_n,
    input  logic       restart_n,
    input  logic       start_n,
    input  logic [1:0] product_sw,
    input  logic [2:0] coins_sw,

    output logic [2:0] delivery_led_n,
    output logic [2:0] empty_led_n,
    output logic       refund_led,
    output logic [3:0] an,
    output logic [7:0] sseg
);

    // ==========================================
    // 1. SINCRONIZACION DE ENTRADAS
    // ==========================================
    // S1 afirma reset de inmediato; su liberacion pasa por dos registros.
    logic reset_first;
    logic reset;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            reset_first <= 1'b1;
            reset <= 1'b1;
        end else begin
            reset_first <= 1'b0;
            reset <= reset_first;
        end
    end

    logic [3:0] inputs_sync_a;
    logic [3:0] inputs_sync_b;

    // Sincronizador A: bits 0 y 1 para START y RESTART; bits 2 y 3 para producto.
    synchronizer sync_a (
        .clk(clk),
        .reset(reset),
        .async_in({product_sw, restart_n, start_n}),
        .sync_out(inputs_sync_a)
    );

    // Sincronizador B: bits 0 a 2 para monedas; bit 3 fijo en alto.
    synchronizer sync_b (
        .clk(clk),
        .reset(reset),
        .async_in({1'b1, coins_sw}),
        .sync_out(inputs_sync_b)
    );

    // ==========================================
    // 2. ANTIRREBOTE
    // ==========================================
    // Los contactos usan pull-up: presionado o cerrado se convierte en uno.
    logic start_pressed_sync;
    logic restart_pressed_sync;
    logic [1:0] product_sync;
    logic [2:0] coins_sync;
    logic start_db;
    logic restart_db;
    logic [1:0] product_db;
    logic [2:0] coins_db;

    assign start_pressed_sync = ~inputs_sync_a[0];
    assign restart_pressed_sync = ~inputs_sync_a[1];
    assign product_sync = ~inputs_sync_a[3:2];
    assign coins_sync = ~inputs_sync_b[2:0];

    // Cada canal tiene su propio contador de antirrebote.
    debouncer #(.N(DEBOUNCE_N)) debounce_start (
        .clk(clk), .n_reset(~reset),
        .button_in(start_pressed_sync), .DB_out(start_db)
    );

    debouncer #(.N(DEBOUNCE_N)) debounce_restart (
        .clk(clk), .n_reset(~reset),
        .button_in(restart_pressed_sync), .DB_out(restart_db)
    );

    debouncer #(.N(DEBOUNCE_N)) debounce_product_0 (
        .clk(clk), .n_reset(~reset),
        .button_in(product_sync[0]), .DB_out(product_db[0])
    );

    debouncer #(.N(DEBOUNCE_N)) debounce_product_1 (
        .clk(clk), .n_reset(~reset),
        .button_in(product_sync[1]), .DB_out(product_db[1])
    );

    debouncer #(.N(DEBOUNCE_N)) debounce_coins_0 (
        .clk(clk), .n_reset(~reset),
        .button_in(coins_sync[0]), .DB_out(coins_db[0])
    );

    debouncer #(.N(DEBOUNCE_N)) debounce_coins_1 (
        .clk(clk), .n_reset(~reset),
        .button_in(coins_sync[1]), .DB_out(coins_db[1])
    );

    debouncer #(.N(DEBOUNCE_N)) debounce_coins_2 (
        .clk(clk), .n_reset(~reset),
        .button_in(coins_sync[2]), .DB_out(coins_db[2])
    );

    // La ventana incluye el antirrebote y un margen para sus registros.
    localparam int unsigned STABLE_CYCLES = (1 << (DEBOUNCE_N - 1)) + 8;
    logic [6:0] inputs_now;
    logic [6:0] inputs_previous;
    logic [31:0] startup_count;
    logic inputs_ready;

    assign inputs_now = {coins_sync, product_sync,
                         restart_pressed_sync, start_pressed_sync};

    // Esta espera se realiza una sola vez despues de cada reset.
    always_ff @(posedge clk) begin
        if (reset) begin
            inputs_previous <= 7'd0;
            startup_count <= 32'd0;
            inputs_ready <= 1'b0;
        end else begin
            inputs_previous <= inputs_now;
            if (!inputs_ready) begin
                if (inputs_now != inputs_previous)
                    startup_count <= 32'd0;
                else if (startup_count == STABLE_CYCLES - 1)
                    inputs_ready <= 1'b1;
                else
                    startup_count <= startup_count + 32'd1;
            end
        end
    end

    // Los cinco DIP deben formar una palabra estable antes de START.
    logic [4:0] dips_now;
    logic [4:0] dips_previous;
    logic [31:0] dips_count;
    logic dips_ready;

    assign dips_now = {coins_sync, product_sync};
    assign dips_ready = inputs_ready &&
                        (dips_count == STABLE_CYCLES) &&
                        (dips_now == dips_previous) &&
                        (dips_now == {coins_db, product_db});

    always_ff @(posedge clk) begin
        if (reset) begin
            dips_previous <= 5'd0;
            dips_count <= 32'd0;
        end else begin
            dips_previous <= dips_now;
            if (dips_now != dips_previous)
                dips_count <= 32'd0;
            else if (dips_count < STABLE_CYCLES)
                dips_count <= dips_count + 32'd1;
        end
    end

    // ==========================================
    // 3. CONTROL DE START Y RESTART
    // ==========================================
    logic start_previous;
    logic restart_previous;
    logic start_armed;
    logic restart_armed;
    logic start_event;
    logic restart_event;

    // Un boton mantenido durante reset debe soltarse antes de habilitarse.
    always_ff @(posedge clk) begin
        if (reset) begin
            start_previous <= 1'b0;
            restart_previous <= 1'b0;
            start_armed <= 1'b0;
            restart_armed <= 1'b0;
            start_event <= 1'b0;
            restart_event <= 1'b0;
        end else begin
            start_previous <= start_db;
            restart_previous <= restart_db;
            start_event <= 1'b0;
            restart_event <= 1'b0;

            if (inputs_ready) begin
                if (!start_db)
                    start_armed <= 1'b1;
                else if (start_armed && !start_previous) begin
                    start_event <= 1'b1;
                    start_armed <= 1'b0;
                end

                if (!restart_db)
                    restart_armed <= 1'b1;
                else if (restart_armed && !restart_previous) begin
                    restart_event <= 1'b1;
                    restart_armed <= 1'b0;
                end
            end
        end
    end

    // ==========================================
    // 4. CAPTURA DE PRODUCTO Y MONEDAS
    // ==========================================
    logic [1:0] product_held;
    logic [9:0] credit_held;
    logic transaction_busy;
    logic request_pending;
    logic request_event;
    logic clear_transaction;

    // Primero guardar los datos; despues enviar la solicitud al sistema.
    always_ff @(posedge clk) begin
        if (reset) begin
            product_held <= 2'b00;
            credit_held <= 10'd0;
            transaction_busy <= 1'b0;
            request_pending <= 1'b0;
            request_event <= 1'b0;
        end else begin
            request_pending <= 1'b0;
            request_event <= request_pending;

            if (clear_transaction)
                transaction_busy <= 1'b0;
            else if (start_event && dips_ready && !transaction_busy &&
                     !refund_led && (product_db != 2'b11)) begin
                product_held <= product_db;
                transaction_busy <= 1'b1;
                request_pending <= 1'b1;

                // IN_COINS indica cantidad de monedas, no el importe.
                case (coins_db)
                    3'd0: credit_held <= 10'd0;
                    3'd1: credit_held <= 10'd100;
                    3'd2: credit_held <= 10'd200;
                    3'd3: credit_held <= 10'd300;
                    3'd4: credit_held <= 10'd400;
                    3'd5: credit_held <= 10'd500;
                    3'd6: credit_held <= 10'd600;
                    3'd7: credit_held <= 10'd700;
                    default: credit_held <= 10'd0;
                endcase
            end
        end
    end

    // ==========================================
    // 5. SISTEMA DE MAQUINA EXPENDEDORA
    // ==========================================
    logic [1:0] inventory_A;
    logic [1:0] inventory_B;
    logic [1:0] inventory_C;
    logic empty_A;
    logic empty_B;
    logic empty_C;
    logic decrement_A;
    logic decrement_B;
    logic decrement_C;
    logic refund_active;
    logic [9:0] change_reg;

    // La FSM y la ruta de datos originales conservan todas sus funciones.
    vending_system system_inst (
        .clk(clk),
        .reset(reset),
        .request_event(request_event),
        .restart_event(restart_event),
        .product_sel_in(product_held),
        .credit_in(credit_held),
        .product_sel_reg(),
        .selection_valid(),
        .product_valid(),
        .price_reg(),
        .credit_reg(),
        .inventory_A(inventory_A),
        .inventory_B(inventory_B),
        .inventory_C(inventory_C),
        .empty_A(empty_A),
        .empty_B(empty_B),
        .empty_C(empty_C),
        .magnitude(),
        .negative(),
        .result_valid(),
        .selected_available(),
        .purchase_authorized(),
        .credit_captured(),
        .capture_credit(),
        .load_selection(),
        .load_price(),
        .load_credit(),
        .calculate_balance(),
        .change_reg(change_reg),
        .load_change(),
        .decrement_A(decrement_A),
        .decrement_B(decrement_B),
        .decrement_C(decrement_C),
        .refund_active(refund_active),
        .clear_transaction(clear_transaction)
    );

    // ==========================================
    // 6. INDICADORES Y DISPLAY DEL VUELTO
    // ==========================================
    logic [2:0] delivery_saved;
    logic refund_visible;
    logic refund_done;

    // Bit 0 = A, bit 1 = B, bit 2 = C. Los LED integrados son activos bajos.
    assign delivery_led_n = ~delivery_saved;
    assign empty_led_n = ~{empty_C, empty_B, empty_A};

    always_ff @(posedge clk) begin
        if (reset)
            delivery_saved <= 3'b000;
        else if (clear_transaction)
            delivery_saved <= 3'b000;
        else if (decrement_A || decrement_B || decrement_C)
            delivery_saved <= {decrement_C, decrement_B, decrement_A};
    end

    // El LED externo es activo alto y no se borra al limpiar la transaccion.
    // Al llegar done, la salida se apaga sin agregar otro ciclo al intervalo.
    assign refund_led = refund_visible && !refund_done;

    always_ff @(posedge clk) begin
        if (reset)
            refund_visible <= 1'b0;
        else if (refund_active)
            refund_visible <= 1'b1;
        else if (refund_done)
            refund_visible <= 1'b0;
    end

    // A 27 MHz, 54 millones de ciclos equivalen a dos segundos.
    // Cada evento rearma el temporizador; REFUND_CYCLES debe ser mayor que cero.
    timer_2s #(.TIMER_CYCLES(REFUND_CYCLES)) refund_timer (
        .clk(clk),
        .reset(reset),
        .clear(refund_active),
        .enable(refund_visible),
        .done(refund_done)
    );

    // El vuelto ya esta registrado antes de mostrar la entrega.
    // Ambos permanecen visibles hasta el RESTART aceptado por el nucleo.
    logic display_enable;
    assign display_enable = (delivery_saved != 3'b000);

    vending_display #(
        .DISPLAY_DIV(DISPLAY_DIV),
        .SEGMENTS_ACTIVE_LOW(SEGMENTS_ACTIVE_LOW),
        .DIGITS_ACTIVE_LOW(DIGITS_ACTIVE_LOW)
    ) display_inst (
        .clk(clk),
        .reset(reset),
        .value(change_reg),
        .enable(display_enable),
        .an(an),
        .sseg(sseg)
    );

endmodule

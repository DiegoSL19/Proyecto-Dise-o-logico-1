module keypad_frontend #(
    parameter int unsigned DEBOUNCE_N = 21
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick_keypad,
    input  logic [3:0] rows_async,
    output logic [3:0] columns,
    output logic [3:0] key_code,
    output logic       key_press
);

    logic [3:0] rows_sync;
    logic [1:0] row_index;
    logic [1:0] column_index;
    logic       key_detected;
    logic [3:0] decoded_key_code;
    logic       decoded_key_valid;
    logic       tick_keypad_delayed;
    logic [3:0] latched_key_code;
    logic       raw_pressed;
    logic       debounced_pressed;
    logic       debounced_pressed_d;

    synchronizer rows_synchronizer (
        .clk      (clk),
        .reset    (reset),
        .async_in (rows_async),
        .sync_out (rows_sync)
    );

    keypad_scanner scanner (
        .clk          (clk),
        .reset        (reset),
        .tick_keypad  (tick_keypad),
        .rows         (rows_sync),
        .columns      (columns),
        .row_index    (row_index),
        .column_index (column_index),
        .key_detected (key_detected)
    );

    keypad_decoder decoder (
        .row_index    (row_index),
        .column_index (column_index),
        .key_detected (key_detected),
        .key_code     (decoded_key_code),
        .key_valid    (decoded_key_valid)
    );

    always_ff @(posedge clk) begin
        if (reset)
            tick_keypad_delayed <= 1'b0;
        else
            tick_keypad_delayed <= tick_keypad;
    end

    keypad_event event_builder (
        .clk              (clk),
        .reset            (reset),
        .tick_keypad      (tick_keypad_delayed),
        .key_code         (decoded_key_code),
        .key_valid        (decoded_key_valid),
        .latched_key_code (latched_key_code),
        .raw_pressed      (raw_pressed)
    );

    debouncer #(
        .N(DEBOUNCE_N)
    ) press_debouncer (
        .clk       (clk),
        .n_reset   (~reset),
        .button_in (raw_pressed),
        .DB_out    (debounced_pressed)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            debounced_pressed_d <= 1'b0;
            key_press <= 1'b0;
            key_code <= 4'h0;
        end else begin
            debounced_pressed_d <= debounced_pressed;
            key_press <= debounced_pressed & ~debounced_pressed_d;
            if (debounced_pressed && !debounced_pressed_d)
                key_code <= latched_key_code;
        end
    end

endmodule

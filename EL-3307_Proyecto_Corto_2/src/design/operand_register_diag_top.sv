module operand_register_diag_top (
    input  logic       clk,
    input  logic       reset_n,
    input  logic [3:0] rows,
    output logic [3:0] columns,
    output logic [3:0] an,
    output logic [7:0] sseg
);

    logic reset_internal;
    logic tick_keypad;
    logic tick_display_unused;
    logic [3:0] key_code;
    logic key_press;
    logic load_digit;
    logic clear;
    logic [9:0] value;
    logic [3:0] an_internal;
    logic [7:0] sseg_internal;

    assign reset_internal = ~reset_n;
    assign load_digit = key_press;
    assign clear = key_press && (key_code == 4'hD);

    tick_generator #(
        .KEYPAD_DIV(27_000)
    ) tick_unit (
        .clk          (clk),
        .reset        (reset_internal),
        .tick_keypad  (tick_keypad),
        .tick_display (tick_display_unused)
    );

    keypad_frontend #(
        .DEBOUNCE_N(21)
    ) frontend (
        .clk         (clk),
        .reset       (reset_internal),
        .tick_keypad (tick_keypad),
        .rows_async  (rows),
        .columns     (columns),
        .key_code    (key_code),
        .key_press   (key_press)
    );

    operand_register register_unit (
        .clk        (clk),
        .reset      (reset_internal),
        .clear      (clear),
        .load_digit (load_digit),
        .digit      (key_code),
        .value      (value)
    );

    // Mostrar el codigo final del frontend y el registro real en hexadecimal.
    disp_hex_mux #(
        .N(18)
    ) mux_display (
        .clk   (clk),
        .reset (reset_internal),
        .hex3  (key_code),
        .hex2  ({2'b00, value[9:8]}),
        .hex1  (value[7:4]),
        .hex0  (value[3:0]),
        .dp_in (4'b1111),
        .an    (an_internal),
        .sseg  (sseg_internal)
    );

    assign an = ~an_internal;
    assign sseg = ~sseg_internal;

endmodule

module calculator_input_diag_top (
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
    logic [9:0] operand_a;
    logic [9:0] operand_b;
    logic [9:0] magnitude;
    logic negative;
    logic result_valid;
    logic show_result;
    logic show_operand_b;
    logic [3:0] last_key_code;
    logic key_press;
    logic [3:0] an_internal;
    logic [7:0] sseg_internal;

    assign reset_internal = ~reset_n;

    tick_generator #(
        .KEYPAD_DIV(27_000)
    ) tick_unit (
        .clk          (clk),
        .reset        (reset_internal),
        .tick_keypad  (tick_keypad),
        .tick_display (tick_display_unused)
    );

    calculator_system #(
        .DEBOUNCE_N(21)
    ) calculator_unit (
        .clk            (clk),
        .reset          (reset_internal),
        .tick_keypad    (tick_keypad),
        .rows_async     (rows),
        .columns        (columns),
        .operand_a      (operand_a),
        .operand_b      (operand_b),
        .magnitude      (magnitude),
        .negative       (negative),
        .result_valid   (result_valid),
        .show_result    (show_result),
        .show_operand_b (show_operand_b),
        .last_key_code  (last_key_code),
        .key_press      (key_press)
    );

    // Mostrar el codigo final y el operando A real, sin conversion BCD.
    disp_hex_mux #(
        .N(18)
    ) mux_display (
        .clk   (clk),
        .reset (reset_internal),
        .hex3  (last_key_code),
        .hex2  ({2'b00, operand_a[9:8]}),
        .hex1  (operand_a[7:4]),
        .hex0  (operand_a[3:0]),
        .dp_in (4'b1111),
        .an    (an_internal),
        .sseg  (sseg_internal)
    );

    assign an = ~an_internal;
    assign sseg = ~sseg_internal;

endmodule

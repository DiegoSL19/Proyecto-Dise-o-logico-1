module top #(
    parameter int unsigned KEYPAD_DIV = 27_000,
    parameter int unsigned DEBOUNCE_N = 21,
    parameter int unsigned DISPLAY_MUX_N = 18
) (
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
        .KEYPAD_DIV(KEYPAD_DIV)
    ) tick_unit (
        .clk          (clk),
        .reset        (reset_internal),
        .tick_keypad  (tick_keypad),
        .tick_display (tick_display_unused)
    );

    calculator_system #(
        .DEBOUNCE_N(DEBOUNCE_N)
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

    // El refresco del display usa el contador interno de disp_hex_mux.
    calculator_display #(
        .MUX_N(DISPLAY_MUX_N)
    ) display_unit (
        .clk            (clk),
        .reset          (reset_internal),
        .operand_a      (operand_a),
        .operand_b      (operand_b),
        .magnitude      (magnitude),
        .negative       (negative),
        .show_result    (show_result),
        .show_operand_b (show_operand_b),
        .an             (an_internal),
        .sseg           (sseg_internal)
    );

    assign an   = ~an_internal;
    assign sseg = ~sseg_internal;

endmodule

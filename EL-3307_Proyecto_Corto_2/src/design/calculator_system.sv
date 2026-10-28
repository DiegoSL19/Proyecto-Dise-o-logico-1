module calculator_system #(
    parameter int unsigned DEBOUNCE_N = 21
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick_keypad,
    input  logic [3:0] rows_async,
    output logic [3:0] columns,
    output logic [9:0] operand_a,
    output logic [9:0] operand_b,
    output logic [9:0] magnitude,
    output logic       negative,
    output logic       result_valid,
    output logic       show_result,
    output logic       show_operand_b,
    output logic [3:0] last_key_code,
    output logic       key_press
);

    keypad_frontend #(
        .DEBOUNCE_N(DEBOUNCE_N)
    ) frontend (
        .clk         (clk),
        .reset       (reset),
        .tick_keypad (tick_keypad),
        .rows_async  (rows_async),
        .columns     (columns),
        .key_code    (last_key_code),
        .key_press   (key_press)
    );

    calculator_core core (
        .clk          (clk),
        .reset        (reset),
        .key_valid    (key_press),
        .key_code     (last_key_code),
        .operand_a    (operand_a),
        .operand_b    (operand_b),
        .magnitude    (magnitude),
        .negative     (negative),
        .result_valid (result_valid),
        .show_result  (show_result),
        .show_operand_b (show_operand_b)
    );

endmodule

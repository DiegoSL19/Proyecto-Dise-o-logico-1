module calculator_core (
    input  logic       clk,
    input  logic       reset,
    input  logic       key_valid,
    input  logic [3:0] key_code,
    output logic [9:0] operand_a,
    output logic [9:0] operand_b,
    output logic [9:0] magnitude,
    output logic       negative,
    output logic       result_valid,
    output logic       show_result,
    output logic       show_operand_b
);

    logic load_a;
    logic load_b;
    logic clear_a;
    logic clear_b;
    logic calculate;

    calculator_fsm fsm (
        .clk         (clk),
        .reset       (reset),
        .key_valid   (key_valid),
        .key_code    (key_code),
        .load_a      (load_a),
        .load_b      (load_b),
        .clear_a     (clear_a),
        .clear_b     (clear_b),
        .calculate   (calculate),
        .show_result (show_result),
        .show_operand_b (show_operand_b)
    );

    operand_register register_a (
        .clk        (clk),
        .reset      (reset),
        .clear      (clear_a),
        .load_digit (load_a),
        .digit      (key_code),
        .value      (operand_a)
    );

    operand_register register_b (
        .clk        (clk),
        .reset      (reset),
        .clear      (clear_b),
        .load_digit (load_b),
        .digit      (key_code),
        .value      (operand_b)
    );

    subtractor result_unit (
        .clk          (clk),
        .reset        (reset),
        .calculate    (calculate),
        .operand_a    (operand_a),
        .operand_b    (operand_b),
        .magnitude    (magnitude),
        .negative     (negative),
        .result_valid (result_valid)
    );

endmodule

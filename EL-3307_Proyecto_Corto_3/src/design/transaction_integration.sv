module transaction_integration (
    input  logic       clk,
    input  logic       reset,
    input  logic       restart,
    input  logic       load_selection,
    input  logic [1:0] product_sel_in,
    input  logic [9:0] credit_in,
    input  logic       load_price,
    input  logic       load_credit,
    input  logic       calculate_balance,
    output logic [1:0] product_sel_reg,
    output logic       selection_valid,
    output logic       product_valid,
    output logic [9:0] price_reg,
    output logic [9:0] credit_reg,
    output logic [1:0] inventory_A,
    output logic [1:0] inventory_B,
    output logic [1:0] inventory_C,
    output logic       empty_A,
    output logic       empty_B,
    output logic       empty_C,
    output logic [9:0] magnitude,
    output logic       negative,
    output logic       result_valid,
    output logic       selected_available,
    output logic       purchase_authorized
);

    logic       transaction_reset;
    logic       arithmetic_reset;
    logic       arithmetic_product_valid;
    logic       arithmetic_result_valid;
    logic       load_selection_accepted;
    logic       load_price_accepted;
    logic       load_credit_accepted;
    logic       calculate_balance_accepted;

    assign transaction_reset = reset || restart;

    assign load_selection_accepted =
        load_selection && !reset && !restart;

    assign arithmetic_reset =
        transaction_reset || load_selection_accepted;

    assign load_price_accepted =
        load_price &&
        selection_valid &&
        !load_selection &&
        !reset &&
        !restart;

    assign load_credit_accepted =
        load_credit &&
        selection_valid &&
        !load_selection &&
        !reset &&
        !restart;

    assign calculate_balance_accepted =
        calculate_balance &&
        selection_valid &&
        !load_selection &&
        !load_price &&
        !load_credit &&
        !reset &&
        !restart;

    product_selection_register product_selection_register_inst (
        .clk(clk),
        .reset(transaction_reset),
        .load_selection(load_selection_accepted),
        .product_sel_in(product_sel_in),
        .product_sel_reg(product_sel_reg),
        .selection_valid(selection_valid)
    );

    arithmetic_path arithmetic_path_inst (
        .clk(clk),
        .reset(arithmetic_reset),
        .product_sel(product_sel_reg),
        .credit_in(credit_in),
        .load_price(load_price_accepted),
        .load_credit(load_credit_accepted),
        .calculate_balance(calculate_balance_accepted),
        .product_valid(arithmetic_product_valid),
        .price_reg(price_reg),
        .credit_reg(credit_reg),
        .magnitude(magnitude),
        .negative(negative),
        .result_valid(arithmetic_result_valid)
    );

    inventory_register inventory_register_inst (
        .clk(clk),
        .reset(reset),
        .decrement_A(1'b0),
        .decrement_B(1'b0),
        .decrement_C(1'b0),
        .inventory_A(inventory_A),
        .inventory_B(inventory_B),
        .inventory_C(inventory_C),
        .empty_A(empty_A),
        .empty_B(empty_B),
        .empty_C(empty_C)
    );

    assign product_valid =
        selection_valid &&
        arithmetic_product_valid &&
        !load_selection &&
        !reset &&
        !restart;

    // The subtractor's result_valid is a one-cycle pulse. Suppress it as soon
    // as a new selection, operand load, calculation, or reset is requested.
    assign result_valid =
        arithmetic_result_valid &&
        selection_valid &&
        !load_selection &&
        !load_price &&
        !load_credit &&
        !calculate_balance &&
        !reset &&
        !restart;

    purchase_decision purchase_decision_inst (
        .product_sel(product_sel_reg),
        .product_valid(product_valid),
        .empty_A(empty_A),
        .empty_B(empty_B),
        .empty_C(empty_C),
        .result_valid(result_valid),
        .negative(negative),
        .selected_available(selected_available),
        .purchase_authorized(purchase_authorized)
    );

endmodule

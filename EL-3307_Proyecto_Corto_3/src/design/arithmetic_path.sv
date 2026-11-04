module arithmetic_path (
    input  logic       clk,
    input  logic       reset,
    input  logic [1:0] product_sel,
    input  logic [9:0] credit_in,
    input  logic       load_price,
    input  logic       load_credit,
    input  logic       calculate_balance,
    output logic       product_valid,
    output logic [9:0] price_reg,
    output logic [9:0] credit_reg,
    output logic [9:0] magnitude,
    output logic       negative,
    output logic       result_valid
);

    logic [9:0] selected_price;
    logic [1:0] loaded_product_sel;
    logic       price_loaded_valid;
    logic       credit_loaded_valid;
    logic       load_price_accepted;
    logic       load_credit_accepted;
    logic       calculate_accepted;

    price_selector price_selector_inst (
        .product_sel(product_sel),
        .price_value(selected_price),
        .product_valid(product_valid)
    );

    assign load_price_accepted = load_price && product_valid;
    assign load_credit_accepted = load_credit && product_valid;
    assign calculate_accepted =
        calculate_balance &&
        !reset &&
        !load_price &&
        !load_credit &&
        product_valid &&
        price_loaded_valid &&
        credit_loaded_valid &&
        (product_sel == loaded_product_sel);

    transaction_operands transaction_operands_inst (
        .clk(clk),
        .reset(reset),
        .price_in(selected_price),
        .credit_in(credit_in),
        .load_price(load_price_accepted),
        .load_credit(load_credit_accepted),
        .price_reg(price_reg),
        .credit_reg(credit_reg)
    );

    subtractor subtractor_inst (
        .clk(clk),
        .reset(reset),
        .calculate(calculate_accepted),
        .operand_a(credit_reg),
        .operand_b(price_reg),
        .magnitude(magnitude),
        .negative(negative),
        .result_valid(result_valid)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            price_loaded_valid <= 1'b0;
            credit_loaded_valid <= 1'b0;
            loaded_product_sel <= 2'b00;
        // A product change starts a fresh qualification for the current selection.
        end else if (!product_valid ||
                     ((price_loaded_valid || credit_loaded_valid) &&
                      (product_sel != loaded_product_sel))) begin
            price_loaded_valid <= load_price_accepted;
            credit_loaded_valid <= load_credit_accepted;
            if (load_price_accepted || load_credit_accepted)
                loaded_product_sel <= product_sel;
        // One accepted calculation consumes its operand qualification.
        end else if (calculate_accepted) begin
            price_loaded_valid <= 1'b0;
            credit_loaded_valid <= 1'b0;
        end else if (load_price || load_credit) begin
            // A new load after a complete pair begins another transaction;
            // loads can still be paired across cycles while only one is valid.
            if (price_loaded_valid && credit_loaded_valid) begin
                price_loaded_valid <= load_price_accepted;
                credit_loaded_valid <= load_credit_accepted;
            end else begin
                price_loaded_valid <= price_loaded_valid || load_price_accepted;
                credit_loaded_valid <= credit_loaded_valid || load_credit_accepted;
            end

            if (load_price_accepted || load_credit_accepted)
                loaded_product_sel <= product_sel;
        end
    end

endmodule

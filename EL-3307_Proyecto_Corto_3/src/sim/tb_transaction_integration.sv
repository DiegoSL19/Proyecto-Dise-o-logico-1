module tb_transaction_integration;

    logic clk;
    logic reset;
    logic restart;
    logic load_selection;
    logic [1:0] product_sel_in;
    logic [9:0] credit_in;
    logic load_price;
    logic load_credit;
    logic calculate_balance;
    logic [1:0] product_sel_reg;
    logic selection_valid;
    logic product_valid;
    logic [9:0] price_reg;
    logic [9:0] credit_reg;
    logic [1:0] inventory_A;
    logic [1:0] inventory_B;
    logic [1:0] inventory_C;
    logic empty_A;
    logic empty_B;
    logic empty_C;
    logic [9:0] magnitude;
    logic negative;
    logic result_valid;
    logic selected_available;
    logic purchase_authorized;
    logic [9:0] expected_magnitude_state;
    logic expected_negative_state;

    integer tests_run;
    integer errors;

    transaction_integration dut (
        .clk(clk),
        .reset(reset),
        .restart(restart),
        .load_selection(load_selection),
        .product_sel_in(product_sel_in),
        .credit_in(credit_in),
        .load_price(load_price),
        .load_credit(load_credit),
        .calculate_balance(calculate_balance),
        .product_sel_reg(product_sel_reg),
        .selection_valid(selection_valid),
        .product_valid(product_valid),
        .price_reg(price_reg),
        .credit_reg(credit_reg),
        .inventory_A(inventory_A),
        .inventory_B(inventory_B),
        .inventory_C(inventory_C),
        .empty_A(empty_A),
        .empty_B(empty_B),
        .empty_C(empty_C),
        .magnitude(magnitude),
        .negative(negative),
        .result_valid(result_valid),
        .selected_available(selected_available),
        .purchase_authorized(purchase_authorized)
    );

    always #5 clk = ~clk;

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check_state(
        input string label,
        input logic [1:0] expected_selection,
        input logic expected_selection_valid,
        input logic [9:0] expected_price,
        input logic [9:0] expected_credit,
        input logic [1:0] expected_inventory_A,
        input logic [1:0] expected_inventory_B,
        input logic [1:0] expected_inventory_C,
        input logic [9:0] expected_magnitude,
        input logic expected_negative,
        input logic expected_result_valid,
        input logic expected_available,
        input logic expected_authorized
    );
        logic [42:0] actual;
        logic [42:0] expected;
        begin
            #1;
            actual = {
                product_sel_reg,
                selection_valid,
                price_reg,
                credit_reg,
                inventory_A,
                inventory_B,
                inventory_C,
                magnitude,
                negative,
                result_valid,
                selected_available,
                purchase_authorized
            };
            expected = {
                expected_selection,
                expected_selection_valid,
                expected_price,
                expected_credit,
                expected_inventory_A,
                expected_inventory_B,
                expected_inventory_C,
                expected_magnitude,
                expected_negative,
                expected_result_valid,
                expected_available,
                expected_authorized
            };

            tests_run = tests_run + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: sel=%b sel_valid=%b price=%0d credit=%0d inv=%0d/%0d/%0d magnitude=%0d negative=%b result_valid=%b available=%b authorized=%b",
                    label, product_sel_reg, selection_valid, price_reg,
                    credit_reg, inventory_A, inventory_B, inventory_C,
                    magnitude, negative, result_valid, selected_available,
                    purchase_authorized
                );
                $display(
                    "      expected sel=%b sel_valid=%b price=%0d credit=%0d inv=%0d/%0d/%0d magnitude=%0d negative=%b result_valid=%b available=%b authorized=%b",
                    expected_selection, expected_selection_valid,
                    expected_price, expected_credit, expected_inventory_A,
                    expected_inventory_B, expected_inventory_C,
                    expected_magnitude, expected_negative,
                    expected_result_valid, expected_available,
                    expected_authorized
                );
            end else begin
                $display("PASS: %s", label);
            end
        end
    endtask

    task automatic capture_selection(input logic [1:0] selection);
        begin
            product_sel_in = selection;
            load_selection = 1'b1;
            #1;
            tick();
            load_selection = 1'b0;
            #1;
            expected_magnitude_state = 10'd0;
            expected_negative_state = 1'b0;
        end
    endtask

    task automatic load_operands(
        input logic [9:0] credit_value,
        input logic [1:0] expected_selection,
        input logic [9:0] expected_price
    );
        begin
            credit_in = credit_value;
            load_price = 1'b1;
            load_credit = 1'b1;
            tick();
            load_price = 1'b0;
            load_credit = 1'b0;
            check_state("register price and transaction credit",
                        expected_selection, 1'b1, expected_price,
                        credit_value, 2'd3, 2'd3, 2'd3,
                        expected_magnitude_state,
                        expected_negative_state, 1'b0,
                        1'b1, 1'b0);
        end
    endtask

    task automatic calculate_and_check(
        input string label,
        input logic [1:0] expected_selection,
        input logic [9:0] expected_price,
        input logic [9:0] expected_credit,
        input logic [9:0] expected_magnitude,
        input logic expected_negative,
        input logic expected_authorized
    );
        begin
            calculate_balance = 1'b1;
            tick();
            calculate_balance = 1'b0;
            check_state(label, expected_selection, 1'b1, expected_price,
                        expected_credit, 2'd3, 2'd3, 2'd3,
                        expected_magnitude, expected_negative,
                        1'b1, 1'b1, expected_authorized);
            expected_magnitude_state = expected_magnitude;
            expected_negative_state = expected_negative;
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        restart = 1'b0;
        load_selection = 1'b0;
        product_sel_in = 2'b00;
        credit_in = 10'd0;
        load_price = 1'b0;
        load_credit = 1'b0;
        calculate_balance = 1'b0;
        tests_run = 0;
        errors = 0;
        expected_magnitude_state = 10'd0;
        expected_negative_state = 1'b0;

        tick();
        check_state("general synchronous reset",
                    2'b00, 1'b0, 10'd0, 10'd0,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b0, 1'b0);
        reset = 1'b0;

        capture_selection(2'b00);
        check_state("capture product A",
                    2'b00, 1'b1, 10'd0, 10'd0,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b1, 1'b0);

        product_sel_in = 2'b10;
        #1;
        check_state("external DIP change does not alter captured A",
                    2'b00, 1'b1, 10'd0, 10'd0,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b1, 1'b0);
        tick();
        check_state("captured selection remains A without load",
                    2'b00, 1'b1, 10'd0, 10'd0,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b1, 1'b0);

        load_operands(10'd150, 2'b00, 10'd150);
        product_sel_in = 2'b10;
        #1;
        check_state("DIP changes during transaction do not change registered selection",
                    2'b00, 1'b1, 10'd150, 10'd150,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b1, 1'b0);
        capture_selection(2'b00);
        check_state("recapturing the same product invalidates old operands",
                    2'b00, 1'b1, 10'd0, 10'd0,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b1, 1'b0);
        calculate_balance = 1'b1;
        tick();
        calculate_balance = 1'b0;
        check_state("same-product recapture requires fresh operand loads",
                    2'b00, 1'b1, 10'd0, 10'd0,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b1, 1'b0);
        load_operands(10'd150, 2'b00, 10'd150);
        calculate_and_check("exact payment for A", 2'b00, 10'd150,
                            10'd150, 10'd0, 1'b0, 1'b1);
        tick();
        check_state("result is consumed after one valid cycle; stock unchanged",
                    2'b00, 1'b1, 10'd150, 10'd150,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b1, 1'b0);

        capture_selection(2'b01);
        check_state("capture product B",
                    2'b01, 1'b1, 10'd0, 10'd0,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b1, 1'b0);
        load_operands(10'd200, 2'b01, 10'd275);
        calculate_and_check("insufficient payment for B",
                            2'b01, 10'd275, 10'd200, 10'd75, 1'b1, 1'b0);
        tick();
        check_state("insufficient result expires without stock decrement",
                    2'b01, 1'b1, 10'd275, 10'd200,
                    2'd3, 2'd3, 2'd3,
                    10'd75, 1'b1, 1'b0, 1'b1, 1'b0);

        capture_selection(2'b10);
        check_state("capture product C",
                    2'b10, 1'b1, 10'd0, 10'd0,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b1, 1'b0);
        load_operands(10'd500, 2'b10, 10'd400);
        calculate_and_check("overpayment for C",
                            2'b10, 10'd400, 10'd500, 10'd100, 1'b0, 1'b1);
        tick();
        check_state("C transaction result consumed; no automatic decrement",
                    2'b10, 1'b1, 10'd400, 10'd500,
                    2'd3, 2'd3, 2'd3,
                    10'd100, 1'b0, 1'b0, 1'b1, 1'b0);

        capture_selection(2'b00);
        load_operands(10'd200, 2'b00, 10'd150);
        calculate_and_check("overpayment for A",
                            2'b00, 10'd150, 10'd200, 10'd50, 1'b0, 1'b1);

        product_sel_in = 2'b11;
        load_selection = 1'b1;
        #1;
        check_state("invalid capture immediately blocks previous authorization",
                    2'b00, 1'b1, 10'd150, 10'd200,
                    2'd3, 2'd3, 2'd3,
                    10'd50, 1'b0, 1'b0, 1'b0, 1'b0);
        tick();
        load_selection = 1'b0;
        expected_magnitude_state = 10'd0;
        expected_negative_state = 1'b0;
        check_state("invalid selection retains old code but clears its validity",
                    2'b00, 1'b0, 10'd0, 10'd0,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b0, 1'b0);

        calculate_balance = 1'b1;
        tick();
        calculate_balance = 1'b0;
        check_state("calculation with invalid selection is rejected",
                    2'b00, 1'b0, 10'd0, 10'd0,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b0, 1'b0);

        capture_selection(2'b01);
        calculate_balance = 1'b1;
        tick();
        calculate_balance = 1'b0;
        check_state("calculation without new operand loads is rejected",
                    2'b01, 1'b1, 10'd0, 10'd0,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b1, 1'b0);

        load_price = 1'b1;
        load_credit = 1'b0;
        calculate_balance = 1'b1;
        tick();
        load_price = 1'b0;
        calculate_balance = 1'b0;
        check_state("calculation concurrent with operand load is rejected",
                    2'b01, 1'b1, 10'd275, 10'd0,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b1, 1'b0);

        load_credit = 1'b1;
        credit_in = 10'd275;
        tick();
        load_credit = 1'b0;
        check_state("load missing credit for current B transaction",
                    2'b01, 1'b1, 10'd275, 10'd275,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b1, 1'b0);
        calculate_and_check("exact payment for B after fresh loads",
                            2'b01, 10'd275, 10'd275, 10'd0, 1'b0, 1'b1);
        tick();
        check_state("B result expires before next transaction",
                    2'b01, 1'b1, 10'd275, 10'd275,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b1, 1'b0);

        capture_selection(2'b10);
        load_operands(10'd400, 2'b10, 10'd400);
        calculate_and_check("consecutive exact payment for C",
                            2'b10, 10'd400, 10'd400, 10'd0, 1'b0, 1'b1);
        tick();
        check_state("C result consumed and inventories remain unchanged",
                    2'b10, 1'b1, 10'd400, 10'd400,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b1, 1'b0);

        restart = 1'b1;
        tick();
        restart = 1'b0;
        expected_magnitude_state = 10'd0;
        expected_negative_state = 1'b0;
        check_state("RESTART clears transaction selection but preserves inventory",
                    2'b00, 1'b0, 10'd0, 10'd0,
                    2'd3, 2'd3, 2'd3,
                    10'd0, 1'b0, 1'b0, 1'b0, 1'b0);

        capture_selection(2'b00);
        load_operands(10'd150, 2'b00, 10'd150);
        calculate_and_check("transaction after RESTART is independent",
                            2'b00, 10'd150, 10'd150, 10'd0, 1'b0, 1'b1);

        $display("RESULT: %0d tests, %0d errors", tests_run, errors);
        if (errors != 0)
            $fatal(1, "transaction_integration testbench failed");
        $finish;
    end

endmodule

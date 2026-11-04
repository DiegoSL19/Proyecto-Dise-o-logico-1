module tb_purchase_decision;

    logic [1:0] product_sel;
    logic product_valid;
    logic empty_A;
    logic empty_B;
    logic empty_C;
    logic result_valid;
    logic negative;
    logic selected_available;
    logic purchase_authorized;

    integer tests_run;
    integer errors;

    purchase_decision dut (
        .product_sel(product_sel),
        .product_valid(product_valid),
        .empty_A(empty_A),
        .empty_B(empty_B),
        .empty_C(empty_C),
        .result_valid(result_valid),
        .negative(negative),
        .selected_available(selected_available),
        .purchase_authorized(purchase_authorized)
    );

    task automatic check_case(
        input string label,
        input logic [1:0] selection,
        input logic valid,
        input logic is_empty_A,
        input logic is_empty_B,
        input logic is_empty_C,
        input logic balance_valid,
        input logic is_negative,
        input logic expected_available,
        input logic expected_authorized
    );
        begin
            product_sel = selection;
            product_valid = valid;
            empty_A = is_empty_A;
            empty_B = is_empty_B;
            empty_C = is_empty_C;
            result_valid = balance_valid;
            negative = is_negative;
            #1;

            tests_run = tests_run + 1;
            if ({selected_available, purchase_authorized} !==
                {expected_available, expected_authorized}) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: sel=%b valid=%b empty=%b%b%b result_valid=%b negative=%b got available/authorized=%b%b expected=%b%b",
                    label, product_sel, product_valid, empty_A, empty_B,
                    empty_C, result_valid, negative,
                    selected_available, purchase_authorized,
                    expected_available, expected_authorized
                );
            end else begin
                $display("PASS: %s", label);
            end
        end
    endtask

    initial begin
        tests_run = 0;
        errors = 0;

        check_case("A available; sufficient valid payment",
                   2'b00, 1'b1, 1'b0, 1'b1, 1'b1,
                   1'b1, 1'b0, 1'b1, 1'b1);
        check_case("B available; sufficient valid payment",
                   2'b01, 1'b1, 1'b1, 1'b0, 1'b1,
                   1'b1, 1'b0, 1'b1, 1'b1);
        check_case("C available; sufficient valid payment",
                   2'b10, 1'b1, 1'b1, 1'b1, 1'b0,
                   1'b1, 1'b0, 1'b1, 1'b1);

        check_case("A exhausted",
                   2'b00, 1'b1, 1'b1, 1'b0, 1'b0,
                   1'b1, 1'b0, 1'b0, 1'b0);
        check_case("B exhausted",
                   2'b01, 1'b1, 1'b0, 1'b1, 1'b0,
                   1'b1, 1'b0, 1'b0, 1'b0);
        check_case("C exhausted",
                   2'b10, 1'b1, 1'b0, 1'b0, 1'b1,
                   1'b1, 1'b0, 1'b0, 1'b0);

        check_case("invalid selection 11",
                   2'b11, 1'b0, 1'b0, 1'b0, 1'b0,
                   1'b1, 1'b0, 1'b0, 1'b0);
        check_case("invalid selection blocked even if product_valid is inconsistent",
                   2'b11, 1'b1, 1'b0, 1'b0, 1'b0,
                   1'b1, 1'b0, 1'b0, 1'b0);

        check_case("insufficient payment for available product",
                   2'b01, 1'b1, 1'b1, 1'b0, 1'b1,
                   1'b1, 1'b1, 1'b1, 1'b0);
        check_case("result not valid; prior nonnegative sign is ignored",
                   2'b00, 1'b1, 1'b0, 1'b1, 1'b1,
                   1'b0, 1'b0, 1'b1, 1'b0);
        check_case("result not valid; prior negative sign is ignored",
                   2'b10, 1'b1, 1'b1, 1'b1, 1'b0,
                   1'b0, 1'b1, 1'b1, 1'b0);

        check_case("other products exhausted do not affect available A",
                   2'b00, 1'b1, 1'b0, 1'b1, 1'b1,
                   1'b1, 1'b0, 1'b1, 1'b1);
        check_case("other products exhausted do not affect available B",
                   2'b01, 1'b1, 1'b1, 1'b0, 1'b1,
                   1'b1, 1'b0, 1'b1, 1'b1);
        check_case("other products exhausted do not affect available C",
                   2'b10, 1'b1, 1'b1, 1'b1, 1'b0,
                   1'b1, 1'b0, 1'b1, 1'b1);

        check_case("invalid product_valid blocks an otherwise available A",
                   2'b00, 1'b0, 1'b0, 1'b1, 1'b1,
                   1'b1, 1'b0, 1'b0, 1'b0);
        check_case("negative result blocks authorization",
                   2'b10, 1'b1, 1'b0, 1'b0, 1'b0,
                   1'b1, 1'b1, 1'b1, 1'b0);
        check_case("missing result_valid blocks authorization",
                   2'b01, 1'b1, 1'b1, 1'b0, 1'b1,
                   1'b0, 1'b0, 1'b1, 1'b0);
        check_case("unselected inventory state cannot authorize exhausted selection",
                   2'b10, 1'b1, 1'b0, 1'b0, 1'b1,
                   1'b1, 1'b0, 1'b0, 1'b0);

        $display("RESULT: %0d tests, %0d errors", tests_run, errors);
        if (errors != 0)
            $fatal(1, "purchase_decision testbench failed");
        $finish;
    end

endmodule

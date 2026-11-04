module tb_price_selector;

    logic [1:0] product_sel;
    logic [9:0] price_value;
    logic product_valid;

    integer tests_run;
    integer errors;

    price_selector dut (
        .product_sel(product_sel),
        .price_value(price_value),
        .product_valid(product_valid)
    );

    task automatic check_selection(
        input logic [1:0] selection,
        input logic [9:0] expected_price,
        input logic expected_valid,
        input string label
    );
        begin
            product_sel = selection;
            #1;

            tests_run = tests_run + 1;
            if ({price_value, product_valid} !==
                {expected_price, expected_valid}) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: product_sel=%b price_value=%0d product_valid=%b expected_price=%0d expected_valid=%b",
                    label, product_sel, price_value, product_valid,
                    expected_price, expected_valid
                );
            end else begin
                $display("PASS: %s", label);
            end
        end
    endtask

    initial begin
        product_sel = 2'b00;
        tests_run = 0;
        errors = 0;

        check_selection(2'b00, 10'd150, 1'b1, "product A maps to price 150");
        check_selection(2'b01, 10'd275, 1'b1, "product B maps to price 275");
        check_selection(2'b10, 10'd400, 1'b1, "product C maps to price 400");
        check_selection(2'b11, 10'd0, 1'b0, "selection 11 is invalid with price 0");

        $display("RESULT: %0d tests, %0d errors", tests_run, errors);
        if (errors != 0)
            $fatal(1, "price_selector testbench failed");
        $finish;
    end

endmodule

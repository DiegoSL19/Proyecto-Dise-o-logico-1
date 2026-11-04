module tb_arithmetic_path;

    logic clk;
    logic reset;
    logic [1:0] product_sel;
    logic [9:0] credit_in;
    logic load_price;
    logic load_credit;
    logic calculate_balance;
    logic product_valid;
    logic [9:0] price_reg;
    logic [9:0] credit_reg;
    logic [9:0] magnitude;
    logic negative;
    logic result_valid;

    integer tests_run;
    integer errors;

    arithmetic_path dut (
        .clk(clk),
        .reset(reset),
        .product_sel(product_sel),
        .credit_in(credit_in),
        .load_price(load_price),
        .load_credit(load_credit),
        .calculate_balance(calculate_balance),
        .product_valid(product_valid),
        .price_reg(price_reg),
        .credit_reg(credit_reg),
        .magnitude(magnitude),
        .negative(negative),
        .result_valid(result_valid)
    );

    always #5 clk = ~clk;

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check_operands(
        input string label,
        input logic [9:0] expected_price,
        input logic [9:0] expected_credit
    );
        begin
            tests_run = tests_run + 1;
            if ({price_reg, credit_reg} !==
                {expected_price, expected_credit}) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: price_reg=%0d credit_reg=%0d expected_price=%0d expected_credit=%0d",
                    label, price_reg, credit_reg,
                    expected_price, expected_credit
                );
            end else begin
                $display("PASS: %s", label);
            end
        end
    endtask

    task automatic check_result(
        input string label,
        input logic expected_valid,
        input logic [9:0] expected_magnitude,
        input logic expected_negative
    );
        begin
            tests_run = tests_run + 1;
            if ({result_valid, magnitude, negative} !==
                {expected_valid, expected_magnitude, expected_negative}) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: valid=%b magnitude=%0d negative=%b expected_valid=%b expected_magnitude=%0d expected_negative=%b",
                    label, result_valid, magnitude, negative,
                    expected_valid, expected_magnitude, expected_negative
                );
            end else begin
                $display("PASS: %s", label);
            end
        end
    endtask

    task automatic run_transaction(
        input logic [1:0] selection,
        input logic [9:0] credit,
        input logic [9:0] expected_price,
        input logic [9:0] expected_magnitude,
        input logic expected_negative,
        input logic [9:0] previous_magnitude,
        input logic previous_negative,
        input string label
    );
        begin
            @(negedge clk);
            product_sel = selection;
            credit_in = credit;
            load_price = 1'b1;
            load_credit = 1'b1;
            calculate_balance = 1'b0;

            tick();
            check_operands({label, " E0 operands loaded"},
                           expected_price, credit);
            check_result({label, " no valid result before calculate"},
                         1'b0, previous_magnitude, previous_negative);
            load_price = 1'b0;
            load_credit = 1'b0;

            @(negedge clk);
            calculate_balance = 1'b1;
            tick();
            check_result({label, " E1 result valid"},
                         1'b1, expected_magnitude, expected_negative);
            calculate_balance = 1'b0;

            tick();
            check_result({label, " E2 result_valid returns low"},
                         1'b0, expected_magnitude, expected_negative);
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        product_sel = 2'b00;
        credit_in = 10'd0;
        load_price = 1'b0;
        load_credit = 1'b0;
        calculate_balance = 1'b0;
        tests_run = 0;
        errors = 0;

        tick();
        check_operands("reset clears operands", 10'd0, 10'd0);
        check_result("reset clears subtractor validity and result",
                     1'b0, 10'd0, 1'b0);
        reset = 1'b0;

        run_transaction(2'b00, 10'd150, 10'd150, 10'd0, 1'b0,
                        10'd0, 1'b0,
                        "A exact payment");
        run_transaction(2'b00, 10'd200, 10'd150, 10'd50, 1'b0,
                        10'd0, 1'b0,
                        "A overpayment");
        run_transaction(2'b01, 10'd200, 10'd275, 10'd75, 1'b1,
                        10'd50, 1'b0,
                        "B underpayment");
        run_transaction(2'b10, 10'd400, 10'd400, 10'd0, 1'b0,
                        10'd75, 1'b1,
                        "C exact payment");
        run_transaction(2'b10, 10'd500, 10'd400, 10'd100, 1'b0,
                        10'd0, 1'b0,
                        "C overpayment");

        @(negedge clk);
        product_sel = 2'b11;
        credit_in = 10'd999;
        load_price = 1'b1;
        load_credit = 1'b1;
        calculate_balance = 1'b0;
        tick();
        tests_run = tests_run + 1;
        if (product_valid !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL: invalid selection product_valid is low");
        end else begin
            $display("PASS: invalid selection product_valid is low");
        end
        check_operands("invalid selection blocks price and credit loads",
                       10'd400, 10'd500);
        load_price = 1'b0;
        load_credit = 1'b0;

        @(negedge clk);
        calculate_balance = 1'b1;
        tick();
        check_result("invalid selection blocks calculation",
                     1'b0, 10'd100, 1'b0);
        calculate_balance = 1'b0;

        reset = 1'b1;
        load_price = 1'b1;
        load_credit = 1'b1;
        calculate_balance = 1'b1;
        product_sel = 2'b01;
        credit_in = 10'd275;
        tick();
        check_operands("reset during transaction clears operands",
                       10'd0, 10'd0);
        check_result("reset during transaction clears result",
                     1'b0, 10'd0, 1'b0);
        reset = 1'b0;
        load_price = 1'b0;
        load_credit = 1'b0;
        calculate_balance = 1'b0;

        @(negedge clk);
        product_sel = 2'b00;
        credit_in = 10'd150;
        tick();
        check_operands("external operand changes without enables are ignored",
                       10'd0, 10'd0);
        check_result("no calculation request leaves result invalid",
                     1'b0, 10'd0, 1'b0);

        // A price without a newly loaded credit must not reuse old credit.
        @(negedge clk);
        product_sel = 2'b00;
        credit_in = 10'd200;
        load_price = 1'b1;
        load_credit = 1'b1;
        tick();
        check_operands("prepare pair before single-operand transaction",
                       10'd150, 10'd200);
        load_price = 1'b0;
        load_credit = 1'b0;
        @(negedge clk);
        calculate_balance = 1'b1;
        tick();
        check_result("seed previous result for stale-result rejection",
                     1'b1, 10'd50, 1'b0);
        calculate_balance = 1'b0;
        tick();
        check_result("seed result validity expires after one cycle",
                     1'b0, 10'd50, 1'b0);

        @(negedge clk);
        product_sel = 2'b01;
        load_price = 1'b1;
        tick();
        check_operands("new price loads while old credit register is retained",
                       10'd275, 10'd200);
        load_price = 1'b0;
        @(negedge clk);
        calculate_balance = 1'b1;
        tick();
        check_result("new price without new credit rejects calculation",
                     1'b0, 10'd50, 1'b0);
        calculate_balance = 1'b0;

        // A credit-only load after reset is insufficient to enable calculation.
        @(negedge clk);
        reset = 1'b1;
        load_credit = 1'b0;
        tick();
        reset = 1'b0;
        @(negedge clk);
        product_sel = 2'b01;
        credit_in = 10'd300;
        load_credit = 1'b1;
        tick();
        check_operands("credit-only load leaves price register reset",
                       10'd0, 10'd300);
        load_credit = 1'b0;
        @(negedge clk);
        calculate_balance = 1'b1;
        tick();
        check_result("calculation without a loaded price is rejected",
                     1'b0, 10'd0, 1'b0);
        calculate_balance = 1'b0;

        // A price-only load after reset is insufficient to enable calculation.
        @(negedge clk);
        reset = 1'b1;
        tick();
        reset = 1'b0;
        @(negedge clk);
        product_sel = 2'b00;
        load_price = 1'b1;
        tick();
        check_operands("price-only load leaves credit register reset",
                       10'd150, 10'd0);
        load_price = 1'b0;
        @(negedge clk);
        calculate_balance = 1'b1;
        tick();
        check_result("calculation without loaded credit is rejected",
                     1'b0, 10'd0, 1'b0);
        calculate_balance = 1'b0;

        // calculate_balance is suppressed whenever either load is asserted.
        @(negedge clk);
        load_price = 1'b1;
        load_credit = 1'b1;
        credit_in = 10'd200;
        tick();
        check_operands("load both operands before calculate/load collision tests",
                       10'd150, 10'd200);
        load_price = 1'b0;
        load_credit = 1'b0;

        @(negedge clk);
        product_sel = 2'b00;
        load_price = 1'b1;
        calculate_balance = 1'b1;
        tick();
        check_operands("price loads on collision while credit remains stored",
                       10'd150, 10'd200);
        check_result("calculate is blocked while load_price is active",
                     1'b0, 10'd0, 1'b0);
        load_price = 1'b0;
        calculate_balance = 1'b0;
        @(negedge clk);
        calculate_balance = 1'b1;
        tick();
        check_result("price-load collision invalidates old credit qualification",
                     1'b0, 10'd0, 1'b0);
        calculate_balance = 1'b0;

        @(negedge clk);
        reset = 1'b1;
        tick();
        reset = 1'b0;
        @(negedge clk);
        product_sel = 2'b01;
        credit_in = 10'd300;
        load_price = 1'b1;
        load_credit = 1'b1;
        tick();
        check_operands("reload valid pair before credit-load collision",
                       10'd275, 10'd300);
        load_price = 1'b0;
        load_credit = 1'b0;

        @(negedge clk);
        credit_in = 10'd400;
        load_credit = 1'b1;
        calculate_balance = 1'b1;
        tick();
        check_operands("credit loads on collision",
                       10'd275, 10'd400);
        check_result("calculate is blocked while load_credit is active",
                     1'b0, 10'd0, 1'b0);
        load_credit = 1'b0;
        calculate_balance = 1'b0;

        // A changed selection invalidates the previously paired operands.
        @(negedge clk);
        reset = 1'b1;
        tick();
        reset = 1'b0;
        @(negedge clk);
        product_sel = 2'b00;
        credit_in = 10'd200;
        load_price = 1'b1;
        load_credit = 1'b1;
        tick();
        check_operands("load A transaction before changing product selection",
                       10'd150, 10'd200);
        load_price = 1'b0;
        load_credit = 1'b0;
        @(negedge clk);
        product_sel = 2'b01;
        calculate_balance = 1'b1;
        tick();
        check_result("changed product selection rejects calculation",
                     1'b0, 10'd0, 1'b0);
        calculate_balance = 1'b0;

        // Two consecutive transactions must use their own newly loaded credits.
        @(negedge clk);
        reset = 1'b1;
        tick();
        reset = 1'b0;
        run_transaction(2'b00, 10'd200, 10'd150, 10'd50, 1'b0,
                        10'd0, 1'b0, "consecutive transaction 1");
        run_transaction(2'b01, 10'd300, 10'd275, 10'd25, 1'b0,
                        10'd50, 1'b0, "consecutive transaction 2");

        // Independent operand loads may be paired before a calculation.
        @(negedge clk);
        reset = 1'b1;
        tick();
        reset = 1'b0;
        @(negedge clk);
        product_sel = 2'b10;
        load_price = 1'b1;
        tick();
        check_operands("first independent load stages price",
                       10'd400, 10'd0);
        load_price = 1'b0;
        @(negedge clk);
        credit_in = 10'd500;
        load_credit = 1'b1;
        tick();
        check_operands("second independent load completes operand pair",
                       10'd400, 10'd500);
        load_credit = 1'b0;
        @(negedge clk);
        calculate_balance = 1'b1;
        tick();
        check_result("independently loaded pair calculates correctly",
                     1'b1, 10'd100, 1'b0);
        calculate_balance = 1'b0;
        tick();
        check_result("independent-load result validity lasts one cycle",
                     1'b0, 10'd100, 1'b0);

        // Reset after a complete load pair invalidates both load qualifications.
        @(negedge clk);
        reset = 1'b1;
        tick();
        check_operands("new reset clears previously loaded operands",
                       10'd0, 10'd0);
        check_result("new reset clears prior result and validity",
                     1'b0, 10'd0, 1'b0);
        reset = 1'b0;
        @(negedge clk);
        calculate_balance = 1'b1;
        tick();
        check_result("calculation after reset without reload is rejected",
                     1'b0, 10'd0, 1'b0);
        calculate_balance = 1'b0;

        $display("RESULT: %0d tests, %0d errors", tests_run, errors);
        if (errors != 0)
            $fatal(1, "arithmetic_path testbench failed");
        $finish;
    end

endmodule

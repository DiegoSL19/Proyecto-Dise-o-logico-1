module tb_transaction_operands;

    logic clk;
    logic reset;
    logic [9:0] price_in;
    logic [9:0] credit_in;
    logic load_price;
    logic load_credit;
    logic [9:0] price_reg;
    logic [9:0] credit_reg;

    integer tests_run;
    integer errors;

    transaction_operands dut (
        .clk(clk),
        .reset(reset),
        .price_in(price_in),
        .credit_in(credit_in),
        .load_price(load_price),
        .load_credit(load_credit),
        .price_reg(price_reg),
        .credit_reg(credit_reg)
    );

    always #5 clk = ~clk;

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check_registers(
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

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        price_in = 10'd0;
        credit_in = 10'd0;
        load_price = 1'b0;
        load_credit = 1'b0;
        tests_run = 0;
        errors = 0;

        tick();
        check_registers("synchronous reset clears both operand registers",
                        10'd0, 10'd0);
        reset = 1'b0;

        price_in = 10'd150;
        credit_in = 10'd500;
        load_price = 1'b1;
        #1;
        check_registers("price input change does not update before a rising edge",
                        10'd0, 10'd0);
        tick();
        check_registers("price-only load captures 150 and preserves credit",
                        10'd150, 10'd0);
        load_price = 1'b0;

        credit_in = 10'd275;
        load_credit = 1'b1;
        tick();
        check_registers("credit-only load captures 275 and preserves price",
                        10'd150, 10'd275);
        load_credit = 1'b0;

        price_in = 10'd275;
        credit_in = 10'd400;
        load_price = 1'b1;
        load_credit = 1'b1;
        tick();
        check_registers("simultaneous loads capture price 275 and credit 400",
                        10'd275, 10'd400);
        load_price = 1'b0;
        load_credit = 1'b0;

        price_in = 10'd400;
        credit_in = 10'd150;
        #1;
        check_registers("changed inputs with disabled loads leave registers unchanged",
                        10'd275, 10'd400);
        tick();
        check_registers("no-load cycle preserves both registers",
                        10'd275, 10'd400);

        price_in = 10'd400;
        load_price = 1'b1;
        tick();
        check_registers("price-only load captures representative price 400",
                        10'd400, 10'd400);
        load_price = 1'b0;

        price_in = 10'd150;
        credit_in = 10'd275;
        #1;
        check_registers("new input values without enables are not captured",
                        10'd400, 10'd400);
        tick();
        check_registers("registers remain unchanged after disabled-input changes",
                        10'd400, 10'd400);

        price_in = 10'd150;
        credit_in = 10'd275;
        load_price = 1'b1;
        load_credit = 1'b1;
        reset = 1'b1;
        tick();
        check_registers("reset has priority over simultaneous operand loads",
                        10'd0, 10'd0);

        $display("RESULT: %0d tests, %0d errors", tests_run, errors);
        if (errors != 0)
            $fatal(1, "transaction_operands testbench failed");
        $finish;
    end

endmodule

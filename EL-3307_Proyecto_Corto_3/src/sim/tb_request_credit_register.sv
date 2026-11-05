module tb_request_credit_register;

    logic clk;
    logic reset;
    logic capture_credit;
    logic [9:0] credit_in;
    logic [9:0] credit_reg;

    integer tests_run;
    integer errors;

    request_credit_register dut (
        .clk(clk),
        .reset(reset),
        .capture_credit(capture_credit),
        .credit_in(credit_in),
        .credit_reg(credit_reg)
    );

    always #5 clk = ~clk;

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check_credit(
        input string label,
        input logic [9:0] expected
    );
        begin
            tests_run = tests_run + 1;
            if (credit_reg !== expected) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: credit_reg=%0d expected=%0d",
                    label, credit_reg, expected
                );
            end else begin
                $display("PASS: %s", label);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        capture_credit = 1'b0;
        credit_in = 10'd0;
        tests_run = 0;
        errors = 0;

        tick();
        check_credit("reset initializes credit register", 10'd0);

        @(negedge clk);
        reset = 1'b0;
        capture_credit = 1'b1;
        credit_in = 10'd150;
        #1;
        check_credit("150 is not captured before rising edge", 10'd0);
        tick();
        check_credit("capture 150", 10'd150);

        @(negedge clk);
        credit_in = 10'd275;
        tick();
        check_credit("capture 275", 10'd275);

        @(negedge clk);
        credit_in = 10'd400;
        tick();
        check_credit("capture 400", 10'd400);

        @(negedge clk);
        credit_in = 10'd500;
        tick();
        check_credit("capture 500", 10'd500);

        @(negedge clk);
        capture_credit = 1'b0;
        credit_in = 10'd123;
        #1;
        check_credit("input change without enable does not change register",
                     10'd500);
        tick();
        check_credit("disabled capture holds value on rising edge",
                     10'd500);

        @(negedge clk);
        credit_in = 10'd999;
        #1;
        check_credit("another external input change is ignored", 10'd500);
        tick();
        check_credit("register remains unchanged with capture disabled",
                     10'd500);

        @(negedge clk);
        reset = 1'b1;
        capture_credit = 1'b1;
        credit_in = 10'd777;
        #1;
        check_credit("reset does not change register before rising edge",
                     10'd500);
        tick();
        check_credit("reset has priority over enabled capture", 10'd0);

        @(negedge clk);
        reset = 1'b0;
        credit_in = 10'd0;
        tick();
        check_credit("capture zero", 10'd0);

        @(negedge clk);
        credit_in = 10'd1023;
        tick();
        check_credit("capture maximum 10-bit value", 10'd1023);

        @(negedge clk);
        credit_in = 10'd1;
        #1;
        check_credit("credit remains maximum before next rising edge",
                     10'd1023);
        tick();
        check_credit("capture minimum positive value", 10'd1);

        $display("RESULT: %0d tests, %0d errors", tests_run, errors);
        if (errors != 0)
            $fatal(1, "request_credit_register testbench failed");
        $finish;
    end

endmodule

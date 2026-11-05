module tb_change_register;

    logic clk;
    logic reset;
    logic load_change;
    logic [9:0] change_in;
    logic [9:0] change_reg;

    integer tests_run;
    integer errors;

    change_register dut (
        .clk(clk),
        .reset(reset),
        .load_change(load_change),
        .change_in(change_in),
        .change_reg(change_reg)
    );

    always #5 clk = ~clk;

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check_change(
        input string label,
        input logic [9:0] expected
    );
        begin
            tests_run = tests_run + 1;
            if (change_reg !== expected) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: change_reg=%0d expected=%0d",
                    label, change_reg, expected
                );
            end else begin
                $display("PASS: %s", label);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        load_change = 1'b0;
        change_in = 10'd0;
        tests_run = 0;
        errors = 0;

        tick();
        check_change("reset initializes change register", 10'd0);

        @(negedge clk);
        reset = 1'b0;
        load_change = 1'b1;
        change_in = 10'd0;
        tick();
        check_change("store zero change", 10'd0);

        @(negedge clk);
        change_in = 10'd25;
        tick();
        check_change("store change 25", 10'd25);

        @(negedge clk);
        change_in = 10'd50;
        tick();
        check_change("store change 50", 10'd50);

        @(negedge clk);
        change_in = 10'd100;
        tick();
        check_change("store change 100", 10'd100);

        @(negedge clk);
        change_in = 10'd350;
        tick();
        check_change("store change 350", 10'd350);

        @(negedge clk);
        load_change = 1'b0;
        change_in = 10'd123;
        #1;
        check_change("input change without load does not update register",
                     10'd350);
        tick();
        check_change("register holds value when load is disabled", 10'd350);

        @(negedge clk);
        change_in = 10'd700;
        #1;
        check_change("external input changes are ignored", 10'd350);
        tick();
        check_change("disabled register retains stored change", 10'd350);

        @(negedge clk);
        load_change = 1'b1;
        change_in = 10'd75;
        #1;
        check_change("new value is not stored before rising edge", 10'd350);
        tick();
        check_change("value updates on rising edge", 10'd75);

        @(negedge clk);
        reset = 1'b1;
        change_in = 10'd900;
        #1;
        check_change("reset does not change register before rising edge",
                     10'd75);
        tick();
        check_change("reset has priority over load_change", 10'd0);

        @(negedge clk);
        reset = 1'b0;
        change_in = 10'd1023;
        tick();
        check_change("store maximum 10-bit value", 10'd1023);

        @(negedge clk);
        change_in = 10'd1;
        tick();
        check_change("consecutive load stores next value", 10'd1);

        @(negedge clk);
        change_in = 10'd500;
        tick();
        check_change("consecutive load stores another value", 10'd500);

        $display("RESULT: %0d tests, %0d errors", tests_run, errors);
        if (errors != 0)
            $fatal(1, "change_register testbench failed");
        $finish;
    end

endmodule

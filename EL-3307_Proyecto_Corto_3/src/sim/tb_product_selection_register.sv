module tb_product_selection_register;

    logic clk;
    logic reset;
    logic load_selection;
    logic [1:0] product_sel_in;
    logic [1:0] product_sel_reg;
    logic selection_valid;

    integer tests_run;
    integer errors;

    product_selection_register dut (
        .clk(clk),
        .reset(reset),
        .load_selection(load_selection),
        .product_sel_in(product_sel_in),
        .product_sel_reg(product_sel_reg),
        .selection_valid(selection_valid)
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
        input logic expected_valid
    );
        begin
            tests_run = tests_run + 1;
            if ({product_sel_reg, selection_valid} !==
                {expected_selection, expected_valid}) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: product_sel_reg=%b selection_valid=%b expected=%b%b",
                    label, product_sel_reg, selection_valid,
                    expected_selection, expected_valid
                );
            end else begin
                $display("PASS: %s", label);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        load_selection = 1'b0;
        product_sel_in = 2'b00;
        tests_run = 0;
        errors = 0;

        tick();
        check_state("synchronous reset initializes code and validity",
                    2'b00, 1'b0);
        reset = 1'b0;

        product_sel_in = 2'b00;
        load_selection = 1'b1;
        #1;
        check_state("A is not captured before the rising edge",
                    2'b00, 1'b0);
        tick();
        check_state("capture product A",
                    2'b00, 1'b1);

        product_sel_in = 2'b01;
        #1;
        check_state("input change to B does not update without a clock edge",
                    2'b00, 1'b1);
        tick();
        check_state("capture product B",
                    2'b01, 1'b1);

        product_sel_in = 2'b10;
        tick();
        check_state("capture product C",
                    2'b10, 1'b1);

        load_selection = 1'b0;
        product_sel_in = 2'b00;
        #1;
        check_state("disabled load preserves C despite external A input",
                    2'b10, 1'b1);
        tick();
        check_state("no-load clock preserves the registered selection",
                    2'b10, 1'b1);

        product_sel_in = 2'b01;
        #1;
        check_state("external product change without enable is ignored",
                    2'b10, 1'b1);
        load_selection = 1'b1;
        product_sel_in = 2'b11;
        #1;
        check_state("invalid input does not affect registers before clock",
                    2'b10, 1'b1);
        tick();
        check_state("invalid 11 preserves code and clears validity",
                    2'b10, 1'b0);

        product_sel_in = 2'b00;
        tick();
        check_state("valid A capture recovers after invalid selection",
                    2'b00, 1'b1);

        product_sel_in = 2'b01;
        tick();
        check_state("consecutive valid selection B",
                    2'b01, 1'b1);
        product_sel_in = 2'b10;
        tick();
        check_state("consecutive valid selection C",
                    2'b10, 1'b1);
        product_sel_in = 2'b00;
        tick();
        check_state("consecutive valid selection A",
                    2'b00, 1'b1);

        product_sel_in = 2'b10;
        reset = 1'b1;
        tick();
        check_state("reset overrides asserted load_selection",
                    2'b00, 1'b0);

        reset = 1'b0;
        load_selection = 1'b0;
        product_sel_in = 2'b10;
        #1;
        check_state("reset result remains unchanged without a load",
                    2'b00, 1'b0);
        tick();
        check_state("selection_valid remains a capture-validity flag",
                    2'b00, 1'b0);

        $display("RESULT: %0d tests, %0d errors", tests_run, errors);
        if (errors != 0)
            $fatal(1, "product_selection_register testbench failed");
        $finish;
    end

endmodule

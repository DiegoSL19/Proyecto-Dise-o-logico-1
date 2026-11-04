module tb_inventory_register;

    logic clk;
    logic reset;
    logic decrement_A;
    logic decrement_B;
    logic decrement_C;
    logic [1:0] inventory_A;
    logic [1:0] inventory_B;
    logic [1:0] inventory_C;
    logic empty_A;
    logic empty_B;
    logic empty_C;

    integer tests_run;
    integer errors;

    inventory_register dut (
        .clk(clk),
        .reset(reset),
        .decrement_A(decrement_A),
        .decrement_B(decrement_B),
        .decrement_C(decrement_C),
        .inventory_A(inventory_A),
        .inventory_B(inventory_B),
        .inventory_C(inventory_C),
        .empty_A(empty_A),
        .empty_B(empty_B),
        .empty_C(empty_C)
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
        input logic [1:0] expected_A,
        input logic [1:0] expected_B,
        input logic [1:0] expected_C,
        input logic expected_empty_A,
        input logic expected_empty_B,
        input logic expected_empty_C
    );
        begin
            tests_run = tests_run + 1;
            if ({inventory_A, inventory_B, inventory_C,
                 empty_A, empty_B, empty_C} !==
                {expected_A, expected_B, expected_C,
                 expected_empty_A, expected_empty_B, expected_empty_C}) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: inventory=%0d,%0d,%0d empty=%b,%b,%b expected=%0d,%0d,%0d empty=%b,%b,%b",
                    label, inventory_A, inventory_B, inventory_C,
                    empty_A, empty_B, empty_C,
                    expected_A, expected_B, expected_C,
                    expected_empty_A, expected_empty_B, expected_empty_C
                );
            end else begin
                $display("PASS: %s", label);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b0;
        decrement_A = 1'b0;
        decrement_B = 1'b0;
        decrement_C = 1'b0;
        tests_run = 0;
        errors = 0;

        reset = 1'b1;
        tick();
        check_state("synchronous reset initializes all inventories to 3",
                    2'd3, 2'd3, 2'd3, 1'b0, 1'b0, 1'b0);
        reset = 1'b0;

        decrement_A = 1'b1;
        tick();
        decrement_A = 1'b0;
        check_state("A decrements alone; B and C are preserved",
                    2'd2, 2'd3, 2'd3, 1'b0, 1'b0, 1'b0);

        decrement_B = 1'b1;
        tick();
        decrement_B = 1'b0;
        check_state("B decrements alone; A and C are preserved",
                    2'd2, 2'd2, 2'd3, 1'b0, 1'b0, 1'b0);

        decrement_C = 1'b1;
        tick();
        decrement_C = 1'b0;
        check_state("C decrements alone; A and B are preserved",
                    2'd2, 2'd2, 2'd2, 1'b0, 1'b0, 1'b0);

        decrement_A = 1'b1;
        decrement_B = 1'b1;
        decrement_C = 1'b1;
        tick();
        check_state("simultaneous enables decrement all inventories",
                    2'd1, 2'd1, 2'd1, 1'b0, 1'b0, 1'b0);

        tick();
        check_state("simultaneous enables reach zero and assert empty flags",
                    2'd0, 2'd0, 2'd0, 1'b1, 1'b1, 1'b1);

        tick();
        check_state("decrements at zero do not underflow",
                    2'd0, 2'd0, 2'd0, 1'b1, 1'b1, 1'b1);

        decrement_A = 1'b0;
        decrement_B = 1'b0;
        decrement_C = 1'b0;
        reset = 1'b1;
        tick();
        check_state("reset restores inventory before reset-priority test",
                    2'd3, 2'd3, 2'd3, 1'b0, 1'b0, 1'b0);

        reset = 1'b0;
        decrement_A = 1'b1;
        decrement_B = 1'b1;
        decrement_C = 1'b1;
        tick();
        check_state("simultaneous decrements update all three registers",
                    2'd2, 2'd2, 2'd2, 1'b0, 1'b0, 1'b0);

        reset = 1'b1;
        tick();
        check_state("reset has priority over simultaneous decrements",
                    2'd3, 2'd3, 2'd3, 1'b0, 1'b0, 1'b0);

        reset = 1'b0;
        decrement_A = 1'b0;
        decrement_B = 1'b0;
        decrement_C = 1'b0;
        tick();
        check_state("inventories are preserved with no enables",
                    2'd3, 2'd3, 2'd3, 1'b0, 1'b0, 1'b0);

        $display("RESULT: %0d tests, %0d errors", tests_run, errors);
        if (errors != 0)
            $fatal(1, "inventory_register testbench failed");
        $finish;
    end

endmodule

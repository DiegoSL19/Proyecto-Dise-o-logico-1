module tb_timer_2s;

    logic clk;
    logic reset;
    logic clear;
    logic enable;
    logic done;

    integer tests_run;
    integer errors;
    integer i;

    timer_2s #(
        .TIMER_CYCLES(26'd5)
    ) dut (
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .enable(enable),
        .done(done)
    );

    always #5 clk = ~clk;

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check_done(
        input string label,
        input logic expected
    );
        begin
            tests_run = tests_run + 1;
            if (done !== expected) begin
                errors = errors + 1;
                $display("FAIL: %s: done=%b expected=%b",
                         label, done, expected);
            end else begin
                $display("PASS: %s", label);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        clear = 1'b0;
        enable = 1'b0;
        tests_run = 0;
        errors = 0;

        tick();
        check_done("reset initializes done low", 1'b0);

        @(negedge clk);
        reset = 1'b0;
        enable = 1'b1;
        check_done("done is low before counting", 1'b0);
        tick();
        check_done("done stays low after first enabled cycle", 1'b0);
        tick();
        check_done("done stays low before final cycle", 1'b0);
        tick();
        check_done("done stays low with two cycles remaining", 1'b0);

        @(negedge clk);
        enable = 1'b0;
        #1;
        check_done("enable change does not affect output between edges",
                   1'b0);
        repeat (2) begin
            tick();
            check_done("disabled timer remains paused", 1'b0);
        end

        @(negedge clk);
        enable = 1'b1;
        tick();
        check_done("count resumes after pause", 1'b0);
        tick();
        check_done("done asserts on fifth enabled cycle", 1'b1);
        tick();
        check_done("done remains asserted after completion", 1'b1);
        tick();
        check_done("timer does not restart automatically", 1'b1);

        @(negedge clk);
        clear = 1'b1;
        enable = 1'b1;
        #1;
        check_done("clear does not change done before rising edge", 1'b1);
        tick();
        check_done("clear resets done", 1'b0);

        @(negedge clk);
        clear = 1'b0;
        for (i = 1; i < 5; i = i + 1) begin
            enable = 1'b1;
            tick();
            check_done("second run stays low before fifth cycle", 1'b0);
        end
        tick();
        check_done("timer completes a second run", 1'b1);

        @(negedge clk);
        reset = 1'b1;
        clear = 1'b1;
        enable = 1'b1;
        #1;
        check_done("reset does not change done before rising edge", 1'b1);
        tick();
        check_done("reset clears done with clear and enable active", 1'b0);

        @(negedge clk);
        reset = 1'b0;
        clear = 1'b0;
        enable = 1'b1;
        for (i = 1; i < 5; i = i + 1) begin
            tick();
            check_done("reset interrupted count starts again at zero",
                       1'b0);
        end
        tick();
        check_done("reset-priority run completes after five cycles", 1'b1);

        @(negedge clk);
        reset = 1'b1;
        clear = 1'b0;
        enable = 1'b0;
        tick();
        check_done("final reset clears completed timer", 1'b0);

        $display("RESULT: %0d tests, %0d errors", tests_run, errors);
        if (errors != 0)
            $fatal(1, "timer_2s testbench failed");
        $finish;
    end

endmodule

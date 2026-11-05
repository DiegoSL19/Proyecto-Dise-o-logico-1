module tb_vending_system;

    logic clk;
    logic reset;
    logic request_event;
    logic restart_event;
    logic [1:0] product_sel_in;
    logic [9:0] credit_in;
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
    logic [9:0] credit_captured;
    logic       capture_credit;
    logic       load_selection;
    logic load_price;
    logic load_credit;
    logic calculate_balance;
    logic [9:0] change_reg;
    logic load_change;
    logic decrement_A;
    logic decrement_B;
    logic decrement_C;
    logic clear_transaction;

    integer tests_run;
    integer errors;
    integer active_state_bits;
    integer bit_index;
    logic state_has_unknown;

    localparam logic [8:0] ST_REPOSO            = 9'b000000001;
    localparam logic [8:0] ST_CAPTURA_SOLICITUD = 9'b000000010;
    localparam logic [8:0] ST_CARGA_Y_REVISION  = 9'b000000100;
    localparam logic [8:0] ST_LANZAR_CALCULO    = 9'b000001000;
    localparam logic [8:0] ST_CALCULO_SALDO     = 9'b000010000;
    localparam logic [8:0] ST_ENTREGA           = 9'b000100000;
    localparam logic [8:0] ST_ESPERA_RESTART    = 9'b001000000;

    vending_system dut (
        .clk(clk),
        .reset(reset),
        .request_event(request_event),
        .restart_event(restart_event),
        .product_sel_in(product_sel_in),
        .credit_in(credit_in),
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
        .purchase_authorized(purchase_authorized),
        .credit_captured(credit_captured),
        .capture_credit(capture_credit),
        .load_selection(load_selection),
        .load_price(load_price),
        .load_credit(load_credit),
        .calculate_balance(calculate_balance),
        .change_reg(change_reg),
        .load_change(load_change),
        .decrement_A(decrement_A),
        .decrement_B(decrement_B),
        .decrement_C(decrement_C),
        .clear_transaction(clear_transaction)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        #1;
        tests_run = tests_run + 1;
        active_state_bits = 0;
        state_has_unknown = 1'b0;

        for (bit_index = 0; bit_index < 9; bit_index = bit_index + 1) begin
            case (dut.fsm_inst.state_reg[bit_index])
                1'b0: begin end
                1'b1: active_state_bits = active_state_bits + 1;
                default: state_has_unknown = 1'b1;
            endcase
        end

        if (state_has_unknown || (active_state_bits != 1)) begin
            errors = errors + 1;
            $display(
                "FAIL: One-Hot invariant: state=%b active=%0d unknown=%b",
                dut.fsm_inst.state_reg, active_state_bits, state_has_unknown
            );
        end
    end

    task automatic step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check_state(
        input string label,
        input logic [8:0] expected
    );
        begin
            tests_run = tests_run + 1;
            if (dut.fsm_inst.state_reg !== expected) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: state=%b expected=%b",
                    label, dut.fsm_inst.state_reg, expected
                );
            end else begin
                $display("PASS: %s", label);
            end
        end
    endtask

    task automatic check_inventory(
        input string label,
        input logic [1:0] expected_A,
        input logic [1:0] expected_B,
        input logic [1:0] expected_C,
        input logic expected_empty_A,
        input logic expected_empty_B,
        input logic expected_empty_C
    );
        logic [8:0] actual;
        logic [8:0] expected;
        begin
            #1;
            actual = {
                inventory_A, inventory_B, inventory_C,
                empty_A, empty_B, empty_C
            };
            expected = {
                expected_A, expected_B, expected_C,
                expected_empty_A, expected_empty_B, expected_empty_C
            };
            tests_run = tests_run + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: inventory=%0d/%0d/%0d empty=%b%b%b expected=%0d/%0d/%0d empty=%b%b%b",
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

    task automatic check_captured_credit(
        input string label,
        input logic [9:0] expected
    );
        begin
            #1;
            tests_run = tests_run + 1;
            if (credit_captured !== expected) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: credit_captured=%0d expected=%0d",
                    label, credit_captured, expected
                );
            end else begin
                $display("PASS: %s", label);
            end
        end
    endtask

    task automatic check_change(
        input string label,
        input logic [9:0] expected
    );
        begin
            #1;
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

    task automatic check_controls(
        input string label,
        input logic expected_load_selection,
        input logic expected_load_price,
        input logic expected_load_credit,
        input logic expected_calculate,
        input logic expected_A,
        input logic expected_B,
        input logic expected_C,
        input logic expected_clear
    );
        logic [7:0] actual;
        logic [7:0] expected;
        begin
            #1;
            actual = {
                load_selection, load_price, load_credit, calculate_balance,
                decrement_A, decrement_B, decrement_C, clear_transaction
            };
            expected = {
                expected_load_selection, expected_load_price,
                expected_load_credit, expected_calculate,
                expected_A, expected_B, expected_C, expected_clear
            };
            tests_run = tests_run + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: controls=%b expected=%b",
                    label, actual, expected
                );
            end else begin
                $display("PASS: %s", label);
            end

            tests_run = tests_run + 1;
            if ((decrement_A && decrement_B) ||
                (decrement_A && decrement_C) ||
                (decrement_B && decrement_C)) begin
                errors = errors + 1;
                $display("FAIL: %s: multiple decrement outputs asserted", label);
            end else begin
                $display("PASS: %s: decrement outputs mutually exclusive", label);
            end
        end
    endtask

    task automatic check_arithmetic(
        input string label,
        input logic [1:0] expected_selection,
        input logic expected_selection_valid,
        input logic [9:0] expected_price,
        input logic [9:0] expected_credit,
        input logic [9:0] expected_magnitude,
        input logic expected_negative,
        input logic expected_result_valid,
        input logic expected_available,
        input logic expected_authorized
    );
        logic [36:0] actual;
        logic [36:0] expected;
        begin
            #1;
            actual = {
                product_sel_reg, selection_valid, price_reg, credit_reg,
                magnitude, negative, result_valid, selected_available,
                purchase_authorized
            };
            expected = {
                expected_selection, expected_selection_valid,
                expected_price, expected_credit, expected_magnitude,
                expected_negative, expected_result_valid,
                expected_available, expected_authorized
            };
            tests_run = tests_run + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: sel=%b valid=%b price=%0d credit=%0d magnitude=%0d negative=%b result_valid=%b available=%b authorized=%b",
                    label, product_sel_reg, selection_valid, price_reg,
                    credit_reg, magnitude, negative, result_valid,
                    selected_available, purchase_authorized
                );
            end else begin
                $display("PASS: %s", label);
            end
        end
    endtask

    task automatic begin_transaction(
        input logic [1:0] selection,
        input logic [9:0] credit
    );
        begin
            @(negedge clk);
            product_sel_in = selection;
            credit_in = credit;
            request_event = 1'b1;
            #1;
            tests_run = tests_run + 1;
            if (capture_credit !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: accepted START asserts capture_credit");
            end else begin
                $display("PASS: accepted START asserts capture_credit");
            end
            step();
            check_state("request enters CAPTURA_SOLICITUD",
                        ST_CAPTURA_SOLICITUD);
            tests_run = tests_run + 1;
            if (capture_credit !== 1'b0) begin
                errors = errors + 1;
                $display("FAIL: capture_credit ends after START edge");
            end else begin
                $display("PASS: capture_credit ends after START edge");
            end
            check_captured_credit("accepted START captures credit",
                                  credit);
            @(negedge clk);
            request_event = 1'b0;
            check_controls("CAPTURA_SOLICITUD pulses load_selection",
                           1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                           1'b0);
            step();
            check_state("selection captured; enters CARGA_Y_REVISION",
                        ST_CARGA_Y_REVISION);
        end
    endtask

    task automatic complete_successful_purchase(
        input logic [1:0] selection,
        input logic [9:0] credit,
        input logic [9:0] expected_price,
        input logic [9:0] expected_change,
        input logic [1:0] expected_A,
        input logic [1:0] expected_B,
        input logic [1:0] expected_C,
        input logic change_DIP
    );
        begin
            begin_transaction(selection, credit);

            if (change_DIP) begin
                @(negedge clk);
                product_sel_in = selection ^ 2'b01;
                credit_in = 10'd200;
                request_event = 1'b1;
                #1;
                tests_run = tests_run + 1;
                if (capture_credit !== 1'b0) begin
                    errors = errors + 1;
                    $display("FAIL: busy START must not capture a new credit");
                end else begin
                    $display("PASS: busy START does not capture a new credit");
                end
                check_captured_credit("external 200 does not replace captured 500",
                                      credit);
                check_arithmetic("external DIP change cannot alter registered product before E0",
                                 selection, 1'b1, 10'd0, 10'd0,
                                 10'd0, 1'b0, 1'b0, 1'b1, 1'b0);
            end

            check_controls("E0 asserts only price and credit loads",
                           1'b0, 1'b1, 1'b1, 1'b0,
                           1'b0, 1'b0, 1'b0, 1'b0);
            step();
            check_state("E0 advances to LANZAR_CALCULO", ST_LANZAR_CALCULO);
            check_arithmetic("E0 registers operands from this transaction",
                             selection, 1'b1, expected_price, credit,
                             10'd0, 1'b0, 1'b0, 1'b1, 1'b0);
            if (change_DIP) begin
                @(negedge clk);
                request_event = 1'b0;
            end
            check_controls("loads are low and calculate is a one-cycle E1 control",
                           1'b0, 1'b0, 1'b0, 1'b1,
                           1'b0, 1'b0, 1'b0, 1'b0);

            step();
            check_state("E1 advances to CALCULO_SALDO", ST_CALCULO_SALDO);
            check_arithmetic("result and authorization are available after E1",
                             selection, 1'b1, expected_price, credit,
                             expected_change, 1'b0, 1'b1, 1'b1, 1'b1);
            tests_run = tests_run + 1;
            if (load_change !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: authorized result asserts load_change before E2");
            end else begin
                $display("PASS: authorized result asserts load_change before E2");
            end
            check_change("change register holds zero before E2", 10'd0);
            check_controls("calculate pulse is low after E1",
                           1'b0, 1'b0, 1'b0, 1'b0,
                           1'b0, 1'b0, 1'b0, 1'b0);

            step();
            check_state("FSM consumes result_valid and enters ENTREGA at E2",
                        ST_ENTREGA);
            check_change("E2 captures computed change", expected_change);
            tests_run = tests_run + 1;
            if (load_change !== 1'b0) begin
                errors = errors + 1;
                $display("FAIL: load_change deasserts in ENTREGA");
            end else begin
                $display("PASS: load_change deasserts in ENTREGA");
            end
            check_arithmetic("authorization pulse has been consumed after E2",
                             selection, 1'b1, expected_price, credit,
                             expected_change, 1'b0, 1'b0, 1'b1, 1'b0);
            check_controls("ENTREGA asserts exactly the selected decrement",
                           1'b0, 1'b0, 1'b0, 1'b0,
                           (selection == 2'b00),
                           (selection == 2'b01),
                           (selection == 2'b10),
                           1'b0);
            check_inventory("inventory is unchanged until the delivery edge",
                            expected_A, expected_B, expected_C,
                            (expected_A == 0), (expected_B == 0),
                            (expected_C == 0));

            step();
            check_state("delivery edge advances to ESPERA_RESTART",
                        ST_ESPERA_RESTART);
            check_change("change remains stored in ESPERA_RESTART",
                         expected_change);
            check_controls("decrement is low after its single-cycle pulse",
                           1'b0, 1'b0, 1'b0, 1'b0,
                           1'b0, 1'b0, 1'b0, 1'b0);
            case (selection)
                2'b00: expected_A = expected_A - 2'd1;
                2'b01: expected_B = expected_B - 2'd1;
                2'b10: expected_C = expected_C - 2'd1;
                default: begin end
            endcase
            check_inventory("exactly one selected inventory unit was consumed",
                            expected_A, expected_B, expected_C,
                            (expected_A == 0), (expected_B == 0),
                            (expected_C == 0));
        end
    endtask

    task automatic restart_transaction(
        input logic [1:0] expected_A,
        input logic [1:0] expected_B,
        input logic [1:0] expected_C
    );
        begin
            logic [9:0] saved_credit;
            saved_credit = credit_captured;
            @(negedge clk);
            restart_event = 1'b1;
            request_event = 1'b1;
            #1;
            tests_run = tests_run + 1;
            if (capture_credit !== 1'b0) begin
                errors = errors + 1;
                $display("FAIL: START in ESPERA_RESTART must not capture");
            end else begin
                $display("PASS: START in ESPERA_RESTART is ignored");
            end
            check_captured_credit("START during ESPERA_RESTART preserves credit",
                                  saved_credit);
            check_controls("FSM accepts RESTART only in ESPERA_RESTART",
                           1'b0, 1'b0, 1'b0, 1'b0,
                           1'b0, 1'b0, 1'b0, 1'b1);
            step();
            @(negedge clk);
            restart_event = 1'b0;
            request_event = 1'b0;
            check_state("RESTART returns FSM to REPOSO", ST_REPOSO);
            check_inventory("RESTART preserves inventory",
                            expected_A, expected_B, expected_C,
                            (expected_A == 0), (expected_B == 0),
                            (expected_C == 0));
            check_arithmetic("RESTART invalidates transaction data",
                             2'b00, 1'b0, 10'd0, 10'd0,
                             10'd0, 1'b0, 1'b0, 1'b0, 1'b0);
            check_captured_credit("RESTART clears captured credit", 10'd0);
            check_change("RESTART clears stored change", 10'd0);
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        request_event = 1'b0;
        restart_event = 1'b0;
        product_sel_in = 2'b00;
        credit_in = 10'd0;
        tests_run = 0;
        errors = 0;

        step();
        check_state("general reset puts FSM in REPOSO", ST_REPOSO);
        check_inventory("reset initializes inventory to 3/3/3",
                        2'd3, 2'd3, 2'd3, 1'b0, 1'b0, 1'b0);
        check_arithmetic("reset clears transaction arithmetic",
                         2'b00, 1'b0, 10'd0, 10'd0,
                         10'd0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_captured_credit("general reset clears captured credit", 10'd0);
        check_change("general reset clears stored change", 10'd0);
        @(negedge clk);
        reset = 1'b0;

        @(negedge clk);
        restart_event = 1'b1;
        step();
        @(negedge clk);
        restart_event = 1'b0;
        check_state("RESTART in REPOSO does not change state", ST_REPOSO);
        check_controls("RESTART outside wait does not clear transaction",
                       1'b0, 1'b0, 1'b0, 1'b0,
                       1'b0, 1'b0, 1'b0, 1'b0);

        complete_successful_purchase(
            2'b00, 10'd500, 10'd150, 10'd350,
            2'd3, 2'd3, 2'd3, 1'b1
        );
        restart_transaction(2'd2, 2'd3, 2'd3);

        complete_successful_purchase(
            2'b00, 10'd150, 10'd150, 10'd0,
            2'd2, 2'd3, 2'd3, 1'b0
        );
        restart_transaction(2'd1, 2'd3, 2'd3);

        complete_successful_purchase(
            2'b00, 10'd150, 10'd150, 10'd0,
            2'd1, 2'd3, 2'd3, 1'b0
        );
        check_inventory("A is exhausted after its third sale",
                        2'd0, 2'd3, 2'd3, 1'b1, 1'b0, 1'b0);

        restart_transaction(2'd0, 2'd3, 2'd3);
        begin_transaction(2'b00, 10'd150);
        check_controls("exhausted A does not load operands or calculate",
                       1'b0, 1'b0, 1'b0, 1'b0,
                       1'b0, 1'b0, 1'b0, 1'b0);
        check_arithmetic("exhausted A is unavailable and unauthorized",
                         2'b00, 1'b1, 10'd0, 10'd0,
                         10'd0, 1'b0, 1'b0, 1'b0, 1'b0);
        step();
        check_state("exhausted A remains in safe CARGA_Y_REVISION wait",
                    ST_CARGA_Y_REVISION);
        check_controls("no decrement for exhausted A",
                       1'b0, 1'b0, 1'b0, 1'b0,
                       1'b0, 1'b0, 1'b0, 1'b0);

        @(negedge clk);
        reset = 1'b1;
        step();
        check_inventory("general reset recovers exhausted inventory",
                        2'd3, 2'd3, 2'd3, 1'b0, 1'b0, 1'b0);
        check_state("general reset exits safe wait to REPOSO", ST_REPOSO);
        @(negedge clk);
        reset = 1'b0;

        complete_successful_purchase(
            2'b01, 10'd300, 10'd275, 10'd25,
            2'd3, 2'd3, 2'd3, 1'b0
        );
        restart_transaction(2'd3, 2'd2, 2'd3);

        complete_successful_purchase(
            2'b10, 10'd500, 10'd400, 10'd100,
            2'd3, 2'd2, 2'd3, 1'b0
        );

        restart_transaction(2'd3, 2'd2, 2'd2);
        begin_transaction(2'b01, 10'd200);
        check_controls("insufficient-payment transaction loads normally",
                       1'b0, 1'b1, 1'b1, 1'b0,
                       1'b0, 1'b0, 1'b0, 1'b0);
        step();
        check_state("insufficient payment reaches LANZAR_CALCULO",
                    ST_LANZAR_CALCULO);
        step();
        check_state("insufficient payment reaches CALCULO_SALDO",
                    ST_CALCULO_SALDO);
        check_arithmetic("B credit 200 produces shortfall 75",
                         2'b01, 1'b1, 10'd275, 10'd200,
                         10'd75, 1'b1, 1'b1, 1'b1, 1'b0);
        check_change("insufficient payment does not store shortfall as change",
                     10'd0);
        step();
        check_state("insufficient payment remains safely in CALCULO_SALDO",
                    ST_CALCULO_SALDO);
        check_controls("insufficient payment never decrements inventory",
                       1'b0, 1'b0, 1'b0, 1'b0,
                       1'b0, 1'b0, 1'b0, 1'b0);
        check_change("change remains unchanged after result_valid clears",
                     10'd0);
        check_inventory("insufficient payment preserves all inventories",
                        2'd3, 2'd2, 2'd2, 1'b0, 1'b0, 1'b0);

        @(negedge clk);
        reset = 1'b1;
        step();
        check_state("reset safely recovers from insufficient-payment wait",
                    ST_REPOSO);
        check_captured_credit("general reset clears nonzero captured credit",
                              10'd0);
        check_change("general reset clears change register", 10'd0);
        @(negedge clk);
        reset = 1'b0;

        begin_transaction(2'b11, 10'd300);
        check_arithmetic("invalid selection is captured as invalid",
                         2'b00, 1'b0, 10'd0, 10'd0,
                         10'd0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_controls("invalid selection blocks all arithmetic controls",
                       1'b0, 1'b0, 1'b0, 1'b0,
                       1'b0, 1'b0, 1'b0, 1'b0);
        step();
        check_state("invalid selection remains in safe load wait",
                    ST_CARGA_Y_REVISION);
        check_controls("invalid selection produces no decrement",
                       1'b0, 1'b0, 1'b0, 1'b0,
                       1'b0, 1'b0, 1'b0, 1'b0);

        @(negedge clk);
        reset = 1'b1;
        step();
        check_inventory("final general reset restores 3/3/3",
                        2'd3, 2'd3, 2'd3, 1'b0, 1'b0, 1'b0);
        check_state("final reset returns FSM to REPOSO", ST_REPOSO);
        check_captured_credit("final reset clears invalid request credit",
                              10'd0);
        check_change("final reset leaves change register at zero", 10'd0);
        @(negedge clk);
        reset = 1'b0;

        complete_successful_purchase(
            2'b00, 10'd200, 10'd150, 10'd50,
            2'd3, 2'd3, 2'd3, 1'b0
        );



        $display("RESULT: %0d tests, %0d errors", tests_run, errors);
        if (errors != 0)
            $fatal(1, "vending_system testbench failed");
        $finish;
    end

endmodule

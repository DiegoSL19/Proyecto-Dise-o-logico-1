module tb_vending_fsm;

    logic clk;
    logic reset;
    logic request_event;
    logic [1:0] product_sel_in;
    logic       selection_valid;
    logic [1:0] product_sel_reg;
    logic       selected_available;
    logic       result_valid;
    logic       purchase_authorized;
    logic       restart_event;
    logic       load_selection;
    logic       load_price;
    logic       load_credit;
    logic       calculate_balance;
    logic       decrement_A;
    logic       decrement_B;
    logic       decrement_C;
    logic       clear_transaction;
    logic       payment_sufficient;

    integer tests_run;
    integer errors;
    integer active_state_bits;
    integer state_bit_index;
    logic   state_has_unknown;

    localparam logic [8:0] ST_REPOSO            = 9'b000000001;
    localparam logic [8:0] ST_CAPTURA_SOLICITUD = 9'b000000010;
    localparam logic [8:0] ST_CARGA_Y_REVISION  = 9'b000000100;
    localparam logic [8:0] ST_LANZAR_CALCULO    = 9'b000001000;
    localparam logic [8:0] ST_CALCULO_SALDO     = 9'b000010000;
    localparam logic [8:0] ST_ENTREGA           = 9'b000100000;
    localparam logic [8:0] ST_ESPERA_RESTART    = 9'b001000000;
    localparam logic [8:0] ST_DEVOLUCION        = 9'b010000000;
    localparam logic [8:0] ST_RETORNO_REPOSO     = 9'b100000000;

    vending_fsm dut (
        .clk(clk),
        .reset(reset),
        .request_event(request_event),
        .selection_valid(selection_valid),
        .product_sel_reg(product_sel_reg),
        .selected_available(selected_available),
        .result_valid(result_valid),
        .purchase_authorized(purchase_authorized),
        .restart_event(restart_event),
        .load_selection(load_selection),
        .load_price(load_price),
        .load_credit(load_credit),
        .calculate_balance(calculate_balance),
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

        for (state_bit_index = 0; state_bit_index < 9;
             state_bit_index = state_bit_index + 1) begin
            case (dut.state_reg[state_bit_index])
                1'b0: begin end
                1'b1: active_state_bits = active_state_bits + 1;
                default: state_has_unknown = 1'b1;
            endcase
        end

        if (state_has_unknown || (active_state_bits != 1)) begin
            errors = errors + 1;
            $display(
                "FAIL: one-hot invariant after posedge: state=%b active_bits=%0d unknown=%b",
                dut.state_reg, active_state_bits, state_has_unknown
            );
        end
    end

    assign purchase_authorized =
        result_valid &&
        selection_valid &&
        selected_available &&
        payment_sufficient;

    always_ff @(posedge clk) begin
        if (reset || clear_transaction) begin
            product_sel_reg <= 2'b00;
            selection_valid <= 1'b0;
            result_valid <= 1'b0;
        end else begin
            if (load_selection) begin
                case (product_sel_in)
                    2'b00, 2'b01, 2'b10: begin
                        product_sel_reg <= product_sel_in;
                        selection_valid <= 1'b1;
                    end
                    default: begin
                        selection_valid <= 1'b0;
                    end
                endcase
            end

            if (calculate_balance)
                result_valid <= 1'b1;
            else
                result_valid <= 1'b0;
        end
    end

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check_state(
        input string label,
        input logic [8:0] expected_state
    );
        logic [8:0] observed_state;
        begin
            #1;
            observed_state = dut.state_reg;
            tests_run = tests_run + 1;
            if (observed_state !== expected_state) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: state=%b expected=%b",
                    label, observed_state, expected_state
                );
            end else begin
                $display("PASS: %s", label);
            end

            tests_run = tests_run + 1;
            case (observed_state)
                ST_REPOSO,
                ST_CAPTURA_SOLICITUD,
                ST_CARGA_Y_REVISION,
                ST_LANZAR_CALCULO,
                ST_CALCULO_SALDO,
                ST_ENTREGA,
                ST_ESPERA_RESTART,
                ST_DEVOLUCION,
                ST_RETORNO_REPOSO: begin
                    $display("PASS: %s one-hot state invariant", label);
                end
                default: begin
                    errors = errors + 1;
                    $display(
                        "FAIL: %s one-hot state invariant: state=%b",
                        label, observed_state
                    );
                end
            endcase
        end
    endtask

    task automatic check_controls(
        input string label,
        input logic expected_load_selection,
        input logic expected_load_operands,
        input logic expected_calculate,
        input logic expected_dec_A,
        input logic expected_dec_B,
        input logic expected_dec_C,
        input logic expected_clear
    );
        logic [7:0] observed;
        logic [7:0] expected;
        begin
            #1;
            observed = {
                load_selection, load_price, load_credit, calculate_balance,
                decrement_A, decrement_B, decrement_C, clear_transaction
            };
            expected = {
                expected_load_selection,
                expected_load_operands,
                expected_load_operands,
                expected_calculate,
                expected_dec_A,
                expected_dec_B,
                expected_dec_C,
                expected_clear
            };
            tests_run = tests_run + 1;
            if (observed !== expected) begin
                errors = errors + 1;
                $display(
                    "FAIL: %s: controls=%b expected=%b",
                    label, observed, expected
                );
            end else begin
                $display("PASS: %s", label);
            end

            if ((calculate_balance && (load_price || load_credit)) ||
                (decrement_A && decrement_B) ||
                (decrement_A && decrement_C) ||
                (decrement_B && decrement_C)) begin
                tests_run = tests_run + 1;
                errors = errors + 1;
                $display("FAIL: %s: conflicting controls", label);
            end else begin
                tests_run = tests_run + 1;
                $display("PASS: %s: no conflicting controls", label);
            end
        end
    endtask

    task automatic enter_capture(input logic [1:0] selection);
        begin
            @(negedge clk);
            product_sel_in = selection;
            request_event = 1'b1;
            tick();
            request_event = 1'b0;
            check_state("request enters CAPTURA_SOLICITUD", ST_CAPTURA_SOLICITUD);
            check_controls("CAPTURA_SOLICITUD load_selection pulse",
                           1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
            tick();
            check_state("capture advances to CARGA_Y_REVISION",
                        ST_CARGA_Y_REVISION);
        end
    endtask

    task automatic successful_transaction(input logic [1:0] selection);
        begin
            payment_sufficient = 1'b1;
            selected_available = 1'b1;
            enter_capture(selection);
            check_controls("E0 loads price and credit",
                           1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
            tick();
            check_state("E0 advances to LANZAR_CALCULO",
                        ST_LANZAR_CALCULO);
            check_controls("operand loads end before E1",
                           1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);

            tick();
            check_state("E1 advances to CALCULO_SALDO",
                        ST_CALCULO_SALDO);
            check_controls("calculate_balance is a single-cycle pulse",
                           1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
            tests_run = tests_run + 1;
            if (result_valid !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: result_valid is asserted after E1");
            end else begin
                $display("PASS: result_valid is asserted after E1");
            end

            tick();
            check_state("authorized result advances to ENTREGA",
                        ST_ENTREGA);
            check_controls("decrement is selected only for captured product",
                           1'b0, 1'b0, 1'b0,
                           (selection == 2'b00),
                           (selection == 2'b01),
                           (selection == 2'b10),
                           1'b0);
            tick();
            check_state("one delivery cycle advances to ESPERA_RESTART",
                        ST_ESPERA_RESTART);
            check_controls("decrement pulse ends after one cycle",
                           1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        request_event = 1'b0;
        product_sel_in = 2'b00;
        selected_available = 1'b0;
        restart_event = 1'b0;
        payment_sufficient = 1'b0;
        tests_run = 0;
        errors = 0;

        tick();
        check_state("synchronous reset selects REPOSO", ST_REPOSO);
        check_controls("no controls asserted in REPOSO",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        @(negedge clk);
        reset = 1'b0;
        restart_event = 1'b1;
        check_controls("RESTART event in REPOSO is ignored",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        tick();
        restart_event = 1'b0;
        check_state("RESTART outside ESPERA_RESTART leaves REPOSO",
                    ST_REPOSO);

        successful_transaction(2'b00);
        check_controls("RESTART stays inactive without an event in ESPERA_RESTART",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        @(negedge clk);
        restart_event = 1'b1;
        tick();
        restart_event = 1'b0;
        check_state("accepted RESTART returns to REPOSO", ST_REPOSO);

        successful_transaction(2'b01);
        @(negedge clk);
        restart_event = 1'b1;
        check_controls("RESTART control is asserted only in ESPERA_RESTART",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
        tick();
        restart_event = 1'b0;
        check_state("B transaction RESTART returns to REPOSO", ST_REPOSO);

        successful_transaction(2'b10);
        @(negedge clk);
        restart_event = 1'b1;
        tick();
        restart_event = 1'b0;
        check_state("C transaction RESTART returns to REPOSO", ST_REPOSO);

        enter_capture(2'b11);
        selected_available = 1'b1;
        check_controls("invalid selection blocks operand loads",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        tick();
        check_state("invalid selection remains in safe load wait",
                    ST_CARGA_Y_REVISION);

        @(negedge clk);
        reset = 1'b1;
        tick();
        check_state("reset from invalid-selection wait returns to REPOSO",
                    ST_REPOSO);
        @(negedge clk);
        reset = 1'b0;

        selected_available = 1'b0;
        enter_capture(2'b00);
        check_controls("unavailable product blocks price and credit loads",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        tick();
        check_state("exhausted product remains in safe load wait",
                    ST_CARGA_Y_REVISION);

        @(negedge clk);
        reset = 1'b1;
        tick();
        check_state("reset from exhausted-product wait returns to REPOSO",
                    ST_REPOSO);
        @(negedge clk);
        reset = 1'b0;

        selected_available = 1'b1;
        payment_sufficient = 1'b0;
        enter_capture(2'b10);
        tick();
        check_state("insufficient-payment path reaches LANZAR_CALCULO",
                    ST_LANZAR_CALCULO);
        tick();
        check_state("insufficient-payment calculation waits for result",
                    ST_CALCULO_SALDO);
        tick();
        check_state("insufficient payment remains safely in CALCULO_SALDO",
                    ST_CALCULO_SALDO);
        check_controls("insufficient payment produces no decrement",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);

        @(negedge clk);
        reset = 1'b1;
        tick();
        check_state("reset from calculation wait returns to REPOSO",
                    ST_REPOSO);
        @(negedge clk);
        reset = 1'b0;

        $display("RESULT: %0d tests, %0d errors", tests_run, errors);
        if (errors != 0)
            $fatal(1, "vending_fsm testbench failed");
        $finish;
    end

endmodule

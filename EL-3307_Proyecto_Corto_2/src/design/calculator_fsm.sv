module calculator_fsm (
    input  logic       clk,
    input  logic       reset,
    input  logic       key_valid,
    input  logic [3:0] key_code,
    output logic       load_a,
    output logic       load_b,
    output logic       clear_a,
    output logic       clear_b,
    output logic       calculate,
    output logic       show_result,
    output logic       show_operand_b
);

    typedef enum logic [2:0] {
        IDLE,
        INPUT_A,
        INPUT_B,
        CALCULATE,
        SHOW_RESULT
    } state_t;

    state_t state, next_state;
    logic decimal_digit;

    assign decimal_digit =
        (!key_code[3]) || (key_code[3:1] == 3'b100);

    // Reset sincrono, activo en alto.
    always_ff @(posedge clk) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (key_valid && decimal_digit)
                    next_state = INPUT_A;
            end
            INPUT_A: begin
                if (key_valid && (key_code == 4'hA))
                    next_state = INPUT_B;
            end
            INPUT_B: begin
                if (key_valid && (key_code == 4'hB))
                    next_state = CALCULATE;
            end
            CALCULATE: begin
                next_state = SHOW_RESULT;
            end
            SHOW_RESULT: begin
                next_state = state;
            end
            default: begin
                next_state = IDLE;
            end
        endcase

        if (key_valid && (key_code == 4'hD))
            next_state = IDLE;
    end

    always_comb begin
        load_a      = 1'b0;
        load_b      = 1'b0;
        clear_a     = 1'b0;
        clear_b     = 1'b0;
        calculate   = 1'b0;
        show_result = 1'b0;
        show_operand_b = 1'b0;

        if (reset || (key_valid && (key_code == 4'hD))) begin
            clear_a = 1'b1;
            clear_b = 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    clear_a = 1'b1;
                    clear_b = 1'b1;
                    if (key_valid && decimal_digit) begin
                        clear_a = 1'b0;
                        load_a = 1'b1;
                    end
                end
                INPUT_A: begin
                    if (key_valid && decimal_digit)
                        load_a = 1'b1;
                end
                INPUT_B: begin
                    show_operand_b = 1'b1;
                    if (key_valid && decimal_digit)
                        load_b = 1'b1;
                end
                CALCULATE: begin
                    show_operand_b = 1'b1;
                    calculate = 1'b1;
                end
                SHOW_RESULT: begin
                    show_result = 1'b1;
                end
                default: begin
                    // Las salidas conservan sus valores predeterminados.
                end
            endcase
        end
    end

endmodule

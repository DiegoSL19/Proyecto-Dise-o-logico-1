module vending_fsm (
    input  logic       clk,
    input  logic       reset,
    input  logic       request_event,
    input  logic       selection_valid,
    input  logic [1:0] product_sel_reg,
    input  logic       selected_available,
    input  logic       result_valid,
    input  logic       purchase_authorized,
    input  logic       restart_event,
    output logic       load_selection,
    output logic       load_price,
    output logic       load_credit,
    output logic       calculate_balance,
    output logic       decrement_A,
    output logic       decrement_B,
    output logic       decrement_C,
    output logic       clear_transaction
);

    typedef enum logic [8:0] {
        REPOSO              = 9'b000000001,
        CAPTURA_SOLICITUD   = 9'b000000010,
        CARGA_Y_REVISION    = 9'b000000100,
        LANZAR_CALCULO      = 9'b000001000,
        CALCULO_SALDO       = 9'b000010000,
        ENTREGA             = 9'b000100000,
        ESPERA_RESTART      = 9'b001000000,
        DEVOLUCION          = 9'b010000000,
        RETORNO_REPOSO       = 9'b100000000
    } state_t;

    state_t state_reg;
    state_t next_state;

    always_ff @(posedge clk) begin
        if (reset)
            state_reg <= REPOSO;
        else
            state_reg <= next_state;
    end

    always_comb begin
        next_state = state_reg;
        load_selection = 1'b0;
        load_price = 1'b0;
        load_credit = 1'b0;
        calculate_balance = 1'b0;
        decrement_A = 1'b0;
        decrement_B = 1'b0;
        decrement_C = 1'b0;
        clear_transaction = 1'b0;

        if (reset) begin
            next_state = REPOSO;
        end else begin
            case (state_reg)
                REPOSO: begin
                    if (request_event)
                        next_state = CAPTURA_SOLICITUD;
                end

                CAPTURA_SOLICITUD: begin
                    load_selection = 1'b1;
                    next_state = CARGA_Y_REVISION;
                end

                CARGA_Y_REVISION: begin
                    if (selection_valid && selected_available) begin
                        load_price = 1'b1;
                        load_credit = 1'b1;
                        next_state = LANZAR_CALCULO;
                    end
                end

                LANZAR_CALCULO: begin
                    calculate_balance = 1'b1;
                    next_state = CALCULO_SALDO;
                end

                CALCULO_SALDO: begin
                    if (result_valid && purchase_authorized)
                        next_state = ENTREGA;
                end

                ENTREGA: begin
                    if (selection_valid) begin
                        case (product_sel_reg)
                            2'b00: decrement_A = 1'b1;
                            2'b01: decrement_B = 1'b1;
                            2'b10: decrement_C = 1'b1;
                            default: begin
                                decrement_A = 1'b0;
                                decrement_B = 1'b0;
                                decrement_C = 1'b0;
                            end
                        endcase
                    end
                    next_state = ESPERA_RESTART;
                end

                ESPERA_RESTART: begin
                    if (restart_event) begin
                        clear_transaction = 1'b1;
                        next_state = REPOSO;
                    end
                end

                // Diese unvollständigen Pfade bleiben bis zur Klärung sicher stehen.
                DEVOLUCION: begin
                    next_state = DEVOLUCION;
                end

                RETORNO_REPOSO: begin
                    next_state = RETORNO_REPOSO;
                end

                default: begin
                    next_state = REPOSO;
                end
            endcase
        end
    end

endmodule

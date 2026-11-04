module purchase_decision (
    input  logic [1:0] product_sel,
    input  logic       product_valid,
    input  logic       empty_A,
    input  logic       empty_B,
    input  logic       empty_C,
    input  logic       result_valid,
    input  logic       negative,
    output logic       selected_available,
    output logic       purchase_authorized
);

    // The integrator must drive product_sel from the captured transaction,
    // not directly from the physical DIP switches.
    always_comb begin
        selected_available = 1'b0;

        if (product_valid) begin
            case (product_sel)
                2'b00: selected_available = !empty_A;
                2'b01: selected_available = !empty_B;
                2'b10: selected_available = !empty_C;
                default: selected_available = 1'b0;
            endcase
        end

        purchase_authorized =
            product_valid &&
            selected_available &&
            result_valid &&
            !negative;
    end

endmodule

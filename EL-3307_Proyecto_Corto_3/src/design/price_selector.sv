module price_selector (
    input  logic [1:0] product_sel,
    output logic [9:0] price_value,
    output logic       product_valid
);

    // Codificación propuesta: 00=A (150), 01=B (275), 10=C (400), 11=inválido.
    always_comb begin
        price_value = 10'd0;
        product_valid = 1'b0;

        case (product_sel)
            2'b00: begin
                price_value = 10'd150;
                product_valid = 1'b1;
            end
            2'b01: begin
                price_value = 10'd275;
                product_valid = 1'b1;
            end
            2'b10: begin
                price_value = 10'd400;
                product_valid = 1'b1;
            end
            2'b11: begin
                price_value = 10'd0;
                product_valid = 1'b0;
            end
            default: begin
                price_value = 10'd0;
                product_valid = 1'b0;
            end
        endcase
    end

endmodule

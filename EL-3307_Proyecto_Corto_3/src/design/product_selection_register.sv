module product_selection_register (
    input  logic       clk,
    input  logic       reset,
    input  logic       load_selection,
    input  logic [1:0] product_sel_in,
    output logic [1:0] product_sel_reg,
    output logic       selection_valid
);

    always_ff @(posedge clk) begin
        if (reset) begin
            product_sel_reg <= 2'b00;
            selection_valid <= 1'b0;
        end else if (load_selection) begin
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
    end

endmodule

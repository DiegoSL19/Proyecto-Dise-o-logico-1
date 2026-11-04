module transaction_operands (
    input  logic        clk,
    input  logic        reset,
    input  logic [9:0]  price_in,
    input  logic [9:0]  credit_in,
    input  logic        load_price,
    input  logic        load_credit,
    output logic [9:0]  price_reg,
    output logic [9:0]  credit_reg
);

    // Reset lógico síncrono activo alto; la adaptación física de S1 se define aparte.
    always_ff @(posedge clk) begin
        if (reset) begin
            price_reg  <= 10'd0;
            credit_reg <= 10'd0;
        end else begin
            if (load_price)
                price_reg <= price_in;

            if (load_credit)
                credit_reg <= credit_in;
        end
    end

endmodule

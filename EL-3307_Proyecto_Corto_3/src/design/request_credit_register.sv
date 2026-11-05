module request_credit_register (
    input  logic       clk,
    input  logic       reset,
    input  logic       capture_credit,
    input  logic [9:0] credit_in,
    output logic [9:0] credit_reg
);

    always_ff @(posedge clk) begin
        if (reset)
            credit_reg <= 10'd0;
        else if (capture_credit)
            credit_reg <= credit_in;
    end

endmodule

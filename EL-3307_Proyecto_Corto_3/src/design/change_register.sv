module change_register (
    input  logic       clk,
    input  logic       reset,
    input  logic       load_change,
    input  logic [9:0] change_in,
    output logic [9:0] change_reg
);

    always_ff @(posedge clk) begin
        if (reset)
            change_reg <= 10'd0;
        else if (load_change)
            change_reg <= change_in;
    end

endmodule

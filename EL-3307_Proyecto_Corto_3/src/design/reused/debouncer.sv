module debouncer #(
    parameter int unsigned N = 21
) (
    input  logic clk,
    input  logic n_reset,
    input  logic button_in,
    output logic DB_out
);

    logic [N-1:0] q_reg;
    logic [N-1:0] q_next;
    logic DFF1;
    logic DFF2;
    logic q_add;
    logic q_reset;

    assign q_reset = DFF1 ^ DFF2;
    assign q_add = ~q_reg[N-1];

    always_comb begin
        q_next = q_reg;
        if (q_reset)
            q_next = '0;
        else if (q_add)
            q_next = q_reg + 1'b1;
    end

    // Reset sincrono activo en bajo, conforme a la referencia del curso.
    always_ff @(posedge clk) begin
        if (!n_reset) begin
            DFF1 <= 1'b0;
            DFF2 <= 1'b0;
            q_reg <= '0;
        end else begin
            DFF1 <= button_in;
            DFF2 <= DFF1;
            q_reg <= q_next;
        end
    end

    always_ff @(posedge clk) begin
        if (!n_reset)
            DB_out <= 1'b0;
        else if (q_reg[N-1])
            DB_out <= DFF2;
    end

endmodule

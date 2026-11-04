module inventory_register (
    input  logic       clk,
    input  logic       reset,
    input  logic       decrement_A,
    input  logic       decrement_B,
    input  logic       decrement_C,
    output logic [1:0] inventory_A,
    output logic [1:0] inventory_B,
    output logic [1:0] inventory_C,
    output logic       empty_A,
    output logic       empty_B,
    output logic       empty_C
);

    // Reset lógico síncrono activo alto; la polaridad física de S1 debe adaptarse.
    always_ff @(posedge clk) begin
        if (reset) begin
            inventory_A <= 2'd3;
            inventory_B <= 2'd3;
            inventory_C <= 2'd3;
        end else begin
            if (decrement_A && (inventory_A > 2'd0))
                inventory_A <= inventory_A - 2'd1;

            if (decrement_B && (inventory_B > 2'd0))
                inventory_B <= inventory_B - 2'd1;

            if (decrement_C && (inventory_C > 2'd0))
                inventory_C <= inventory_C - 2'd1;
        end
    end

    always_comb begin
        empty_A = (inventory_A == 2'd0);
        empty_B = (inventory_B == 2'd0);
        empty_C = (inventory_C == 2'd0);
    end

endmodule

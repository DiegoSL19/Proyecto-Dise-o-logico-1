module operand_register (
    input  logic       clk,
    input  logic       reset,
    input  logic       clear,
    input  logic       load_digit,
    input  logic [3:0] digit,
    output logic [9:0] value
);

    logic [1:0] digit_count;

    // 14 bits evitan truncamientos intermedios en la multiplicacion y suma.
    logic [13:0] next_value;
    logic decimal_digit;

    assign decimal_digit =
        (!digit[3]) || (digit[3:1] == 3'b100);

    always_comb begin
        next_value = ({4'b0000, value} * 14'd10)
                   + {10'b0000000000, digit};
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            value <= 10'd0;
            digit_count <= 2'd0;
        end else if (clear) begin
            value <= 10'd0;
            digit_count <= 2'd0;
        end else if (load_digit && decimal_digit &&
                     (digit_count < 2'd3)) begin
            value <= next_value[9:0];
            digit_count <= digit_count + 2'd1;
        end
    end

endmodule

module calculator_display #(
    parameter int unsigned MUX_N = 18
) (
    input  logic       clk,
    input  logic       reset,
    input  logic [9:0] operand_a,
    input  logic [9:0] operand_b,
    input  logic [9:0] magnitude,
    input  logic       negative,
    input  logic       show_result,
    input  logic       show_operand_b,
    output logic [3:0] an,
    output logic [7:0] sseg
);

    logic [9:0] display_value;
    logic [11:0] bcd_value;
    logic [3:0] an_mux;
    logic [7:0] sseg_mux;

    always_comb begin
        if (show_result)
            display_value = magnitude;
        else if (show_operand_b)
            display_value = operand_b;
        else
            display_value = operand_a;
    end

    bcd_converter #(
        .N(10),
        .M(12)
    ) bcd_unit (
        .input_bin  (display_value),
        .output_bcd (bcd_value)
    );

    disp_hex_mux #(
        .N(MUX_N)
    ) mux_display (
        .clk   (clk),
        .reset (reset),
        .hex3  (4'h0),
        .hex2  (bcd_value[11:8]),
        .hex1  (bcd_value[7:4]),
        .hex0  (bcd_value[3:0]),
        .dp_in (4'b1111),
        .an    (an_mux),
        .sseg  (sseg_mux)
    );

    always_comb begin
        an = an_mux;
        sseg = sseg_mux;

        if (an_mux == 4'b0111) begin
            // El signo solo se muestra al visualizar un resultado negativo.
            if (show_result && negative)
                sseg = 8'b1_1111110;
            else
                sseg = 8'b1_1111111;
        end else if ((an_mux == 4'b1011) && (bcd_value[11:8] == 4'h0)) begin
            sseg = 8'b1_1111111;
        end else if ((an_mux == 4'b1101) &&
                     (bcd_value[11:8] == 4'h0) && (bcd_value[7:4] == 4'h0)) begin
            sseg = 8'b1_1111111;
        end
        // Las unidades siempre conservan sseg_mux, incluso para el valor cero.
    end

endmodule

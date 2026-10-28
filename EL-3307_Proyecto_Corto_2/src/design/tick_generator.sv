module tick_generator #(
    // Valores provisionales para clk de 27 MHz.
    // Ajustar ambos divisores durante la integracion fisica del teclado y display.
    // Deben ser al menos 2 para separar los pulsos de un ciclo.
    parameter int unsigned KEYPAD_DIV  = 27_000,
    parameter int unsigned DISPLAY_DIV = 6_750
) (
    input  logic clk,
    input  logic reset,
    output logic tick_keypad,
    output logic tick_display
);

    logic [31:0] keypad_count;
    logic [31:0] display_count;

    // Limites constantes calculados en elaboracion.
    localparam int unsigned KEYPAD_LAST = KEYPAD_DIV - 1;
    localparam int unsigned DISPLAY_LAST = DISPLAY_DIV - 1;

    always_ff @(posedge clk) begin
        if (reset) begin
            keypad_count <= 32'd0;
            display_count <= 32'd0;
            tick_keypad <= 1'b0;
            tick_display <= 1'b0;
        end else begin
            tick_keypad <= 1'b0;
            tick_display <= 1'b0;

            if (keypad_count == KEYPAD_LAST) begin
                keypad_count <= 32'd0;
                tick_keypad <= 1'b1;
            end else begin
                keypad_count <= keypad_count + 32'd1;
            end

            if (display_count == DISPLAY_LAST) begin
                display_count <= 32'd0;
                tick_display <= 1'b1;
            end else begin
                display_count <= display_count + 32'd1;
            end
        end
    end

endmodule

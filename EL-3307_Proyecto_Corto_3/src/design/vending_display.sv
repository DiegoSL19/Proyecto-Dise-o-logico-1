module vending_display #(
    parameter int unsigned DISPLAY_DIV = 6_750,
    parameter bit SEGMENTS_ACTIVE_LOW = 1'b0,
    parameter bit DIGITS_ACTIVE_LOW = 1'b0
) (
    input  logic       clk,
    input  logic       reset,
    input  logic [9:0] value,
    input  logic       enable,
    output logic [3:0] an,
    output logic [7:0] sseg
);

    logic [9:0] remainder;
    logic [3:0] thousands;
    logic [8:0] rom_address;
    logic [9:0] rom_value;
    logic [3:0] hundreds;
    logic [11:0] bcd;
    logic tick_display;
    logic [3:0] an_low;
    logic [7:0] sseg_low;

    // La ROM original convierte 0 a 999. Diez bits solo requieren millares 0 o 1.
    always_comb begin
        thousands = 4'd0;
        remainder = value;
        if (value >= 10'd1000) begin
            thousands = 4'd1;
            remainder = value - 10'd1000;
        end
    end

    // Solo se consultan 0 a 499: la ROM de 512x12 cabe en esta FPGA.
    // Si el resto es 500 a 999, sumar cinco a las centenas despues de convertir.
    always_comb begin
        rom_value = remainder;
        hundreds = bcd[11:8];
        if (remainder >= 10'd500) begin
            rom_value = remainder - 10'd500;
            hundreds = bcd[11:8] + 4'd5;
        end
    end
    // rom_value siempre esta entre 0 y 499; el bit 9 es cero.
    assign rom_address = rom_value[8:0];

    bcd_converter #(.N(9), .M(12)) converter (
        .input_bin(rom_address),
        .output_bcd(bcd)
    );

    // El pulso habilita el selector; nunca se usa como un reloj nuevo.
    tick_generator #(.DISPLAY_DIV(DISPLAY_DIV)) refresh (
        .clk(clk),
        .reset(reset),
        .tick_keypad(),
        .tick_display(tick_display)
    );

    disp_hex_mux #(.N(2), .USE_TICK(1'b1)) mux (
        .clk(clk),
        .reset(reset),
        .tick(tick_display),
        .hex3(thousands),
        .hex2(hundreds),
        .hex1(bcd[7:4]),
        .hex0(bcd[3:0]),
        .dp_in(4'b1111),
        .an(an_low),
        .sseg(sseg_low)
    );

    // El formato interno es activo bajo; la salida se adapta al driver fisico.
    // sseg[7] es el punto decimal; sseg[6:0] sigue el orden a, b, c, d, e, f, g.
    always_comb begin
        if (DIGITS_ACTIVE_LOW)
            an = 4'b1111;
        else
            an = 4'b0000;

        if (SEGMENTS_ACTIVE_LOW)
            sseg = 8'hff;
        else
            sseg = 8'h00;

        if (enable && !reset) begin
            if (DIGITS_ACTIVE_LOW)
                an = an_low;
            else
                an = ~an_low;

            if (SEGMENTS_ACTIVE_LOW)
                sseg = sseg_low;
            else
                sseg = ~sseg_low;
        end
    end

endmodule

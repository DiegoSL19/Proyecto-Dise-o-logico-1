module keypad_frontend_diag_top (
    input  logic       clk,
    input  logic       reset_n,
    input  logic [3:0] rows,
    output logic [3:0] columns,
    output logic [3:0] an,
    output logic [7:0] sseg
);

    logic reset_internal;
    logic tick_keypad;
    logic tick_display_unused;
    logic [3:0] key_code;
    logic key_press;
    logic [3:0] saved_key_code;
    logic code_valid;
    logic [3:0] an_internal;
    logic [7:0] sseg_mux;
    logic [7:0] sseg_internal;

    assign reset_internal = ~reset_n;

    tick_generator #(
        .KEYPAD_DIV(27_000)
    ) tick_unit (
        .clk          (clk),
        .reset        (reset_internal),
        .tick_keypad  (tick_keypad),
        .tick_display (tick_display_unused)
    );

    keypad_frontend #(
        .DEBOUNCE_N(21)
    ) frontend (
        .clk         (clk),
        .reset       (reset_internal),
        .tick_keypad (tick_keypad),
        .rows_async  (rows),
        .columns     (columns),
        .key_code    (key_code),
        .key_press   (key_press)
    );

    // El frontend registra key_code y key_press en el mismo flanco.
    // Al observar el pulso en el siguiente flanco, el codigo ya es estable.
    always_ff @(posedge clk) begin
        if (reset_internal) begin
            saved_key_code <= 4'h0;
            code_valid <= 1'b0;
        end else if (key_press) begin
            saved_key_code <= key_code;
            code_valid <= 1'b1;
        end
    end

    disp_hex_mux #(
        .N(18)
    ) mux_display (
        .clk   (clk),
        .reset (reset_internal),
        .hex3  (4'h0),
        .hex2  (4'h0),
        .hex1  (4'h0),
        .hex0  (saved_key_code),
        .dp_in (4'b1111),
        .an    (an_internal),
        .sseg  (sseg_mux)
    );

    always_comb begin
        sseg_internal = 8'hFF;
        if (!reset_internal && code_valid && (an_internal == 4'b1110))
            sseg_internal = sseg_mux;
    end

    assign an = ~an_internal;
    assign sseg = ~sseg_internal;

endmodule

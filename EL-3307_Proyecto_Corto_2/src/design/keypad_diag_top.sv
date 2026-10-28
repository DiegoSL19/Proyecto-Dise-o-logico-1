module keypad_diag_top (
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
    logic [3:0] rows_sync;
    logic [1:0] row_index;
    logic [1:0] column_index;
    logic key_detected;
    logic [3:0] saved_row;
    logic [3:0] saved_column;
    logic position_valid;
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

    synchronizer rows_synchronizer (
        .clk      (clk),
        .reset    (reset_internal),
        .async_in (rows),
        .sync_out (rows_sync)
    );

    keypad_scanner scanner (
        .clk          (clk),
        .reset        (reset_internal),
        .tick_keypad  (tick_keypad),
        .rows         (rows_sync),
        .columns      (columns),
        .row_index    (row_index),
        .column_index (column_index),
        .key_detected (key_detected)
    );

    // El scanner registra indices y deteccion juntos. Capturarlos un ciclo
    // despues, sin usar tick_keypad ni la columna fisica ya adelantada.
    always_ff @(posedge clk) begin
        if (reset_internal) begin
            saved_row <= 4'd0;
            saved_column <= 4'd0;
            position_valid <= 1'b0;
        end else if (key_detected) begin
            saved_row <= {2'b00, row_index} + 4'd1;
            saved_column <= {2'b00, column_index} + 4'd1;
            position_valid <= 1'b1;
        end
    end

    disp_hex_mux #(
        .N(18)
    ) mux_display (
        .clk   (clk),
        .reset (reset_internal),
        .hex3  (4'h0),
        .hex2  (4'h0),
        .hex1  (saved_row),
        .hex0  (saved_column),
        .dp_in (4'b1111),
        .an    (an_internal),
        .sseg  (sseg_mux)
    );

    // Blanquear todos los segmentos, incluido el punto decimal.
    always_comb begin
        sseg_internal = 8'hFF;
        if (!reset_internal && position_valid &&
            ((an_internal == 4'b1101) || (an_internal == 4'b1110)))
            sseg_internal = sseg_mux;
    end

    assign an = ~an_internal;
    assign sseg = ~sseg_internal;

endmodule

module keypad_scanner (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick_keypad,
    input  logic [3:0] rows,
    output logic [3:0] columns,
    output logic [1:0] row_index,
    output logic [1:0] column_index,
    output logic       key_detected
);

    logic [1:0] scan_column;
    logic [1:0] sampled_row;
    logic       single_row_active;

    // El bit 0 corresponde a C1; el bit 3 corresponde a C4.
    always_comb begin
        case (scan_column)
            2'd0: columns = 4'b1110;
            2'd1: columns = 4'b1101;
            2'd2: columns = 4'b1011;
            2'd3: columns = 4'b0111;
            default: columns = 4'b1110;
        endcase
    end

    // Aceptar solamente una fila activa. El bit 0 corresponde a R1.
    always_comb begin
        sampled_row = 2'd0;
        single_row_active = 1'b0;
        case (rows)
            4'b1110: begin
                sampled_row = 2'd0;
                single_row_active = 1'b1;
            end
            4'b1101: begin
                sampled_row = 2'd1;
                single_row_active = 1'b1;
            end
            4'b1011: begin
                sampled_row = 2'd2;
                single_row_active = 1'b1;
            end
            4'b0111: begin
                sampled_row = 2'd3;
                single_row_active = 1'b1;
            end
            default: begin
                sampled_row = 2'd0;
                single_row_active = 1'b0;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            scan_column <= 2'd0;
            row_index <= 2'd0;
            column_index <= 2'd0;
            key_detected <= 1'b0;
        end else begin
            // Pulso de un ciclo para cada muestra valida, sin debounce.
            key_detected <= 1'b0;
            if (tick_keypad) begin
                row_index <= sampled_row;
                column_index <= scan_column;
                key_detected <= single_row_active;
                // Capturar la columna anterior antes de avanzar el barrido.
                scan_column <= scan_column + 2'd1;
            end
        end
    end

endmodule

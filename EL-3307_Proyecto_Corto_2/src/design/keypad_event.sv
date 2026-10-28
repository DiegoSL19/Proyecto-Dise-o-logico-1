module keypad_event (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick_keypad,
    input  logic [3:0] key_code,
    input  logic       key_valid,
    output logic [3:0] latched_key_code,
    output logic       raw_pressed
);

    logic [1:0] scan_count;
    logic       seen_key;
    logic       multiple_keys;
    logic [3:0] candidate_code;
    logic       seen_key_next;
    logic       multiple_keys_next;
    logic [3:0] candidate_code_next;

    // Incluir la muestra actual antes de evaluar el final del barrido.
    always_comb begin
        seen_key_next = seen_key;
        multiple_keys_next = multiple_keys;
        candidate_code_next = candidate_code;

        if (key_valid) begin
            if (seen_key && (key_code != candidate_code))
                multiple_keys_next = 1'b1;
            seen_key_next = 1'b1;
            candidate_code_next = key_code;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            scan_count <= 2'd0;
            seen_key <= 1'b0;
            multiple_keys <= 1'b0;
            candidate_code <= 4'h0;
            latched_key_code <= 4'h0;
            raw_pressed <= 1'b0;
        end else if (tick_keypad) begin
            if (scan_count == 2'd3) begin
                if (seen_key_next && !multiple_keys_next) begin
                    raw_pressed <= 1'b1;
                    latched_key_code <= candidate_code_next;
                end else begin
                    raw_pressed <= 1'b0;
                end

                scan_count <= 2'd0;
                seen_key <= 1'b0;
                multiple_keys <= 1'b0;
                candidate_code <= 4'h0;
            end else begin
                scan_count <= scan_count + 2'd1;
                seen_key <= seen_key_next;
                multiple_keys <= multiple_keys_next;
                candidate_code <= candidate_code_next;
            end
        end
    end

endmodule

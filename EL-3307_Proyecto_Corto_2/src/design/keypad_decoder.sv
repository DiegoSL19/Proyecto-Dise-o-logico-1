module keypad_decoder (
    input  logic [1:0] row_index,
    input  logic [1:0] column_index,
    input  logic       key_detected,
    output logic [3:0] key_code,
    output logic       key_valid
);

    always_comb begin
        key_code = 4'h0;
        key_valid = 1'b0;

        if (key_detected) begin
            key_valid = 1'b1;
            case ({row_index, column_index})
                4'b0000: key_code = 4'h1;
                4'b0001: key_code = 4'h2;
                4'b0010: key_code = 4'h3;
                4'b0011: key_code = 4'hA;
                4'b0100: key_code = 4'h4;
                4'b0101: key_code = 4'h5;
                4'b0110: key_code = 4'h6;
                4'b0111: key_code = 4'hB;
                4'b1000: key_code = 4'h7;
                4'b1001: key_code = 4'h8;
                4'b1010: key_code = 4'h9;
                4'b1011: key_code = 4'hC;
                4'b1100: key_code = 4'hE; // Tecla *.
                4'b1101: key_code = 4'h0;
                4'b1110: key_code = 4'hF; // Tecla # reservada.
                4'b1111: key_code = 4'hD;
                default: key_code = 4'h0;
            endcase
        end
    end

endmodule

module disp_hex_mux #(
    parameter int unsigned N = 18
) (
    input  logic       clk,
    input  logic       reset,
    input  logic [3:0] hex3,
    input  logic [3:0] hex2,
    input  logic [3:0] hex1,
    input  logic [3:0] hex0,
    input  logic [3:0] dp_in,
    output logic [3:0] an,
    output logic [7:0] sseg
);

    // N debe ser al menos 2 para seleccionar con los dos MSB.
    logic [N-1:0] q_reg;
    logic [N-1:0] q_next;
    logic [3:0] hex_in;
    logic dp;

    // Unico reloj: el contador no genera clocks derivados.
    always_ff @(posedge clk) begin
        if (reset)
            q_reg <= '0;
        else
            q_reg <= q_next;
    end

    always_comb begin
        q_next = q_reg + 1'b1;
    end

    always_comb begin
        an = 4'b1111;
        hex_in = 4'h0;
        dp = 1'b1;

        case (q_reg[N-1:N-2])
            2'b00: begin
                an = 4'b1110;
                hex_in = hex0;
                dp = dp_in[0];
            end
            2'b01: begin
                an = 4'b1101;
                hex_in = hex1;
                dp = dp_in[1];
            end
            2'b10: begin
                an = 4'b1011;
                hex_in = hex2;
                dp = dp_in[2];
            end
            2'b11: begin
                an = 4'b0111;
                hex_in = hex3;
                dp = dp_in[3];
            end
        endcase
    end

    // Patrones activos en bajo del curso, en orden a, b, c, d, e, f, g.
    always_comb begin
        sseg[7] = dp;
        case (hex_in)
            4'h0: sseg[6:0] = 7'b0000001;
            4'h1: sseg[6:0] = 7'b1001111;
            4'h2: sseg[6:0] = 7'b0010010;
            4'h3: sseg[6:0] = 7'b0000110;
            4'h4: sseg[6:0] = 7'b1001100;
            4'h5: sseg[6:0] = 7'b0100100;
            4'h6: sseg[6:0] = 7'b0100000;
            4'h7: sseg[6:0] = 7'b0001111;
            4'h8: sseg[6:0] = 7'b0000000;
            4'h9: sseg[6:0] = 7'b0000100;
            4'hA: sseg[6:0] = 7'b0001000;
            4'hB: sseg[6:0] = 7'b1100000;
            4'hC: sseg[6:0] = 7'b0110001;
            4'hD: sseg[6:0] = 7'b1000010;
            4'hE: sseg[6:0] = 7'b0110000;
            4'hF: sseg[6:0] = 7'b0111000;
            default: sseg[6:0] = 7'b1111111;
        endcase
    end

endmodule

`timescale 1ns/1ps

module seven_segment_tb;

    logic [3:0] palabra;
    logic [6:0] catodo;

    seven_segment uut (
        .palabra_pi (palabra),
        .catodo_po  (catodo)
    );

    initial begin
        palabra = 4'h0; #10;
        palabra = 4'h1; #10;
        palabra = 4'h2; #10;
        palabra = 4'h3; #10;
        palabra = 4'h4; #10;
        palabra = 4'h5; #10;
        palabra = 4'h6; #10;
        palabra = 4'h7; #10;
        palabra = 4'h8; #10;
        palabra = 4'h9; #10;
        palabra = 4'hA; #10;
        palabra = 4'hB; #10;
        palabra = 4'hC; #10;
        palabra = 4'hD; #10;
        palabra = 4'hE; #10;
        palabra = 4'hF; #10;

        $finish;
    end

    initial begin
        $dumpfile("seven_segment_tb.vcd");
        $dumpvars(0, seven_segment_tb);
    end

endmodule
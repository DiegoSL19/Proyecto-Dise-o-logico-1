`timescale 1ns/1ps

module TB_TX_01_sin_error;

    reg  [3:0] datos_pi;
    wire       p1_pi;
    wire       p2_pi;
    wire       p4_pi;
    wire       p0_pi;

    reg  [2:0] error1_pi;
    reg  [2:0] error2_pi;
    reg        modo_rx_pi;

    wire [6:0] catodo_po;
    wire [6:0] catodo_rx_po;
    wire [3:0] paridad_led_po;
    wire [7:0] tx_po;

    integer errores;

    // Simula las paridades que en el montaje real generan los 74HC86.
    assign p1_pi = datos_pi[0] ^ datos_pi[1] ^ datos_pi[3];
    assign p2_pi = datos_pi[0] ^ datos_pi[2] ^ datos_pi[3];
    assign p4_pi = datos_pi[1] ^ datos_pi[2] ^ datos_pi[3];
    assign p0_pi = datos_pi[0] ^ datos_pi[1] ^ datos_pi[2];

    top_display dut (
        .datos_pi       (datos_pi),
        .p1_pi          (p1_pi),
        .p2_pi          (p2_pi),
        .p4_pi          (p4_pi),
        .p0_pi          (p0_pi),
        .error1_pi      (error1_pi),
        .error2_pi      (error2_pi),
        .modo_rx_pi     (modo_rx_pi),
        .catodo_po      (catodo_po),
        .catodo_rx_po   (catodo_rx_po),
        .paridad_led_po (paridad_led_po),
        .tx_po          (tx_po)
    );

    task comprobar;
        input condicion;
        input [8*100-1:0] mensaje;
        begin
            if (!condicion) begin
                errores = errores + 1;
                $display("FALLO: %0s", mensaje);
            end
            else
                $display("OK: %0s", mensaje);
        end
    endtask

    initial begin
        $dumpfile("TB_TX_01_sin_error.vcd");
        $dumpvars(0, TB_TX_01_sin_error);

        errores = 0;
        error1_pi = 3'b000;
        error2_pi = 3'b000;
        modo_rx_pi = 1'b0;

        // Caso 1: dato 0
        datos_pi = 4'h0;
        #5;
        comprobar(tx_po === 8'h00,
                  "Dato 0 produce palabra SEC-DED 00000000");

        // Caso 2: dato A
        // D3D2D1D0 = 1010, fisicamente D0D1D2D3 = 0101.
        datos_pi = 4'hA;
        #5;
        comprobar(tx_po === 8'hD2,
                  "Dato A produce TX[7:0] = 11010010 = D2");
        comprobar(catodo_po === 7'h02,
                  "Display TX representa A");

        // Caso 3: dato F
        datos_pi = 4'hF;
        #5;
        comprobar(tx_po === 8'hFF,
                  "Dato F produce palabra SEC-DED 11111111");

        if (errores == 0)
            $display("\nRESULTADO TX 01: TODAS LAS PRUEBAS PASARON.\n");
        else
            $display("\nRESULTADO TX 01: %0d PRUEBAS FALLARON.\n", errores);

        #5;
        $finish;
    end

endmodule

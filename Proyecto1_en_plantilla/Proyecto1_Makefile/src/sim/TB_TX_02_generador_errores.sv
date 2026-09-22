`timescale 1ns/1ps

module TB_TX_02_generador_errores;

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
        $dumpfile("TB_TX_02_generador_errores.vcd");
        $dumpvars(0, TB_TX_02_generador_errores);

        errores = 0;
        datos_pi = 4'hA;
        modo_rx_pi = 1'b0;

        // Palabra correcta de A: D2.
        error1_pi = 3'b000;
        error2_pi = 3'b000;
        #5;
        comprobar(tx_po === 8'hD2,
                  "Sin error, A transmite D2");

        // Error simple en posicion Hamming 3 = D0 = codigo[2].
        error1_pi = 3'b011;
        error2_pi = 3'b000;
        #5;
        comprobar(tx_po === 8'hD6,
                  "Error1=011 invierte D0/codigo[2]: D2 -> D6");

        // Error simple desde el segundo selector, posicion 6 = D2 = codigo[5].
        error1_pi = 3'b000;
        error2_pi = 3'b110;
        #5;
        comprobar(tx_po === 8'hF2,
                  "Error2=110 invierte D2/codigo[5]: D2 -> F2");

        // Dos errores distintos: posiciones 3 y 5.
        error1_pi = 3'b011;
        error2_pi = 3'b101;
        #5;
        comprobar(tx_po === 8'hC6,
                  "Errores en posiciones 3 y 5 producen C6");

        // Si ambos selectores escogen el mismo bit, las dos inversiones se cancelan.
        error1_pi = 3'b011;
        error2_pi = 3'b011;
        #5;
        comprobar(tx_po === 8'hD2,
                  "Dos inversiones sobre la misma posicion se cancelan");

        if (errores == 0)
            $display("\nRESULTADO TX 02: TODAS LAS PRUEBAS PASARON.\n");
        else
            $display("\nRESULTADO TX 02: %0d PRUEBAS FALLARON.\n", errores);

        #5;
        $finish;
    end

endmodule

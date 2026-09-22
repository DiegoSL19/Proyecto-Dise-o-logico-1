`timescale 1ns/1ps

module TB_top_display;

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

    // Simula las paridades generadas fisicamente por los 3 x 74HC86.
    assign p1_pi = datos_pi[0] ^ datos_pi[1] ^ datos_pi[3];
    assign p2_pi = datos_pi[0] ^ datos_pi[2] ^ datos_pi[3];
    assign p4_pi = datos_pi[1] ^ datos_pi[2] ^ datos_pi[3];
    assign p0_pi = datos_pi[0] ^ datos_pi[1] ^ datos_pi[2];

    top_display dut (
        .datos_pi          (datos_pi),
        .p1_pi             (p1_pi),
        .p2_pi             (p2_pi),
        .p4_pi             (p4_pi),
        .p0_pi             (p0_pi),
        .error1_pi         (error1_pi),
        .error2_pi         (error2_pi),
        .modo_rx_pi        (modo_rx_pi),
        .catodo_po         (catodo_po),
        .catodo_rx_po      (catodo_rx_po),
        .paridad_led_po    (paridad_led_po),
        .tx_po             (tx_po)
    );

    task comprobar;
        input condicion;
        input [8*80-1:0] mensaje;
        begin
            if (!condicion) begin
                errores = errores + 1;
                $display("FALLO: %0s", mensaje);
            end
            else begin
                $display("OK: %0s", mensaje);
            end
        end
    endtask

    initial begin
        $dumpfile("proyecto1_tb.vcd");
        $dumpvars(0, TB_top_display);

        errores = 0;

        // A hexadecimal. En el montaje fisico D0 D1 D2 D3 = 0 1 0 1,
        // que en el vector [D3 D2 D1 D0] corresponde a 4'b1010.
        datos_pi   = 4'hA;
        error1_pi  = 3'b000;
        error2_pi  = 3'b000;
        modo_rx_pi = 1'b0;
        #5;

        comprobar(tx_po === 8'hD2,
                  "A sin errores produce TX[7:0] = D2 (11010010)");
        comprobar(catodo_po === 7'h02,
                  "display TX muestra A");
        comprobar(catodo_rx_po === 7'h02,
                  "loopback RX recupera A sin errores");
        comprobar(paridad_led_po[2:0] === 3'b111,
                  "sindrome 000 sin errores (LEDs activos en bajo)");
        comprobar(paridad_led_po[3] === 1'b1,
                  "DED apagado sin doble error");

        // Un error en posicion Hamming 3 = D0.
        error1_pi  = 3'b011;
        error2_pi  = 3'b000;
        modo_rx_pi = 1'b0;
        #5;

        comprobar(tx_po === 8'hD6,
                  "error 011 invierte D0/posicion Hamming 3");
        comprobar(catodo_rx_po === 7'h02,
                  "RX corrige el error simple y recupera A");
        comprobar(paridad_led_po[2:0] === 3'b100,
                  "sindrome 011 para error en posicion 3");
        comprobar(paridad_led_po[3] === 1'b1,
                  "DED permanece apagado con un error");

        // Mostrar el sindrome en el display RX.
        modo_rx_pi = 1'b1;
        #5;
        comprobar(catodo_rx_po === 7'h21,
                  "display RX muestra sindrome 3");

        // Dos errores: posiciones 1 y 2.
        error1_pi  = 3'b001;
        error2_pi  = 3'b010;
        modo_rx_pi = 1'b1;
        #5;

        comprobar(tx_po === 8'hD1,
                  "dos errores distintos modifican dos bits del bus");
        comprobar(paridad_led_po[3] === 1'b0,
                  "DED encendido con dos errores (LED activo en bajo)");
        comprobar(catodo_rx_po === 7'h21,
                  "sindrome resultante 3 para errores en posiciones 1 y 2");

        if (errores == 0)
            $display("\nRESULTADO FINAL: TODAS LAS PRUEBAS PASARON.\n");
        else
            $display("\nRESULTADO FINAL: %0d PRUEBAS FALLARON.\n", errores);

        #5;
        $finish;
    end

endmodule

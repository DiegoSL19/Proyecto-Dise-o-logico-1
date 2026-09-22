`timescale 1ns/1ps

module TB_RX_04_doble_error;

    reg  [7:0] codigo_rx_pi;

    wire [2:0] sindrome_po;
    wire       paridad_error_po;
    wire       error_simple_po;
    wire       error_doble_po;
    wire [7:0] codigo_corregido_po;
    wire [3:0] datos_corregidos_po;

    integer errores;

    receptor_core dut (
        .codigo_rx_pi        (codigo_rx_pi),
        .sindrome_po         (sindrome_po),
        .paridad_error_po    (paridad_error_po),
        .error_simple_po     (error_simple_po),
        .error_doble_po      (error_doble_po),
        .codigo_corregido_po (codigo_corregido_po),
        .datos_corregidos_po (datos_corregidos_po)
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
        $dumpfile("TB_RX_04_doble_error.vcd");
        $dumpvars(0, TB_RX_04_doble_error);

        errores = 0;

        // Palabra correcta para A = D2.
        // Errores en posiciones Hamming 3 y 5:
        // codigo[2] = D0 y codigo[4] = D1.
        // D2 XOR 04 XOR 10 = C6.
        codigo_rx_pi = 8'hC6;
        #5;

        comprobar(sindrome_po === 3'b110,
                  "Dos errores en posiciones 3 y 5 producen sindrome 110");
        comprobar(paridad_error_po === 1'b0,
                  "Dos inversiones conservan paridad global par");
        comprobar(error_simple_po === 1'b0,
                  "No se clasifica como error simple");
        comprobar(error_doble_po === 1'b1,
                  "DED detecta el doble error");
        comprobar(codigo_corregido_po === 8'hC6,
                  "Con doble error el receptor no intenta corregir");
        comprobar(datos_corregidos_po === 4'h9,
                  "Los datos quedan alterados porque DED solo detecta, no corrige");

        if (errores == 0)
            $display("\nRESULTADO RX 04: TODAS LAS PRUEBAS PASARON.\n");
        else
            $display("\nRESULTADO RX 04: %0d PRUEBAS FALLARON.\n", errores);

        #5;
        $finish;
    end

endmodule

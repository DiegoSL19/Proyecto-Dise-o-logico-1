`timescale 1ns/1ps

module TB_RX_01_sin_error;

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
        $dumpfile("TB_RX_01_sin_error.vcd");
        $dumpvars(0, TB_RX_01_sin_error);

        errores = 0;

        // Palabra SEC-DED correcta correspondiente al dato A.
        codigo_rx_pi = 8'hD2;
        #5;

        comprobar(sindrome_po === 3'b000,
                  "Sin error: sindrome = 000");
        comprobar(paridad_error_po === 1'b0,
                  "Sin error: paridad global correcta");
        comprobar(error_simple_po === 1'b0,
                  "Sin error: no se marca error simple");
        comprobar(error_doble_po === 1'b0,
                  "Sin error: DED apagado");
        comprobar(codigo_corregido_po === 8'hD2,
                  "Sin error: la palabra no se modifica");
        comprobar(datos_corregidos_po === 4'hA,
                  "Sin error: se recupera el dato A");

        if (errores == 0)
            $display("\nRESULTADO RX 01: TODAS LAS PRUEBAS PASARON.\n");
        else
            $display("\nRESULTADO RX 01: %0d PRUEBAS FALLARON.\n", errores);

        #5;
        $finish;
    end

endmodule

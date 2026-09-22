`timescale 1ns/1ps

module TB_RX_03_error_P0;

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
        $dumpfile("TB_RX_03_error_P0.vcd");
        $dumpvars(0, TB_RX_03_error_P0);

        errores = 0;

        // Palabra correcta para A = D2.
        // Error exclusivamente en P0 = codigo[7]:
        // D2 XOR 80 = 52.
        codigo_rx_pi = 8'h52;
        #5;

        comprobar(sindrome_po === 3'b000,
                  "Error solo en P0 mantiene sindrome 000");
        comprobar(paridad_error_po === 1'b1,
                  "Error en P0 altera la paridad global");
        comprobar(error_simple_po === 1'b1,
                  "Error en P0 se clasifica como error simple");
        comprobar(error_doble_po === 1'b0,
                  "Error solo en P0 no activa DED");
        comprobar(codigo_corregido_po === 8'hD2,
                  "El receptor corrige P0 y recupera D2");
        comprobar(datos_corregidos_po === 4'hA,
                  "Los datos recuperados corresponden a A");

        if (errores == 0)
            $display("\nRESULTADO RX 03: TODAS LAS PRUEBAS PASARON.\n");
        else
            $display("\nRESULTADO RX 03: %0d PRUEBAS FALLARON.\n", errores);

        #5;
        $finish;
    end

endmodule

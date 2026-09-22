`timescale 1ns/1ps

module sistema_tb;

    // ============================================================
    // TRANSMISOR
    // ============================================================

    logic [3:0] datos;

    logic p1;
    logic p2;
    logic p4;
    logic p0;

    logic [2:0] error_pos1;
    logic [2:0] error_pos2;

    logic [7:0] tx;
    logic [6:0] catodo_tx;


    // ============================================================
    // CANAL DE PRUEBA
    // ============================================================

    // Permite introducir manualmente un error en P0
    // únicamente durante la simulación.
    logic inyectar_p0;

    logic [7:0] rx;

    assign rx =
        inyectar_p0
        ? (tx ^ 8'h80)
        : tx;


    // ============================================================
    // RECEPTOR
    // ============================================================

    logic [2:0] sindrome;
    logic       paridad_error;

    logic       sin_error;
    logic       corregir;
    logic       error_p0;
    logic       ded;

    logic [6:0] palabra_corregida;
    logic [3:0] datos_rx;


    // ============================================================
    // SIMULACIÓN DE LOS 74HC86
    // ============================================================

    assign p1 =
        datos[0] ^
        datos[1] ^
        datos[3];

    assign p2 =
        datos[0] ^
        datos[2] ^
        datos[3];

    assign p4 =
        datos[1] ^
        datos[2] ^
        datos[3];

    assign p0 =
        p1 ^
        p2 ^
        datos[0] ^
        p4 ^
        datos[1] ^
        datos[2] ^
        datos[3];


    // ============================================================
    // INSTANCIA DEL TRANSMISOR
    // ============================================================

    top_tx u_tx (

        .datos_pi      (datos),

        .p1_pi         (p1),
        .p2_pi         (p2),
        .p4_pi         (p4),
        .p0_pi         (p0),

        .error_pos1_pi (error_pos1),
        .error_pos2_pi (error_pos2),

        .tx_po         (tx),
        .catodo_po     (catodo_tx)

    );


    // ============================================================
    // INSTANCIA DEL RECEPTOR
    // ============================================================

    top_rx u_rx (

        .rx_pi                (rx),

        .sindrome_po          (sindrome),
        .paridad_error_po     (paridad_error),

        .sin_error_po         (sin_error),
        .corregir_po          (corregir),
        .error_p0_po          (error_p0),
        .ded_po               (ded),

        .palabra_corregida_po (palabra_corregida),
        .datos_po             (datos_rx)

    );


    // ============================================================
    // FUNCIÓN: CÓDIGO HAMMING ESPERADO
    // ============================================================

    function automatic [7:0] codigo_esperado(
        input logic [3:0] d
    );

        logic q1;
        logic q2;
        logic q4;
        logic q0;

        begin

            q1 =
                d[0] ^
                d[1] ^
                d[3];

            q2 =
                d[0] ^
                d[2] ^
                d[3];

            q4 =
                d[1] ^
                d[2] ^
                d[3];

            q0 =
                q1 ^
                q2 ^
                d[0] ^
                q4 ^
                d[1] ^
                d[2] ^
                d[3];

            codigo_esperado =
                {
                    q0,
                    d[3],
                    d[2],
                    d[1],
                    q4,
                    d[0],
                    q2,
                    q1
                };

        end

    endfunction


    // ============================================================
    // FUNCIÓN: DISPLAY ESPERADO
    // ============================================================

    function automatic [6:0] catodo_esperado(
        input logic [3:0] d
    );

        begin

            case (d)

                4'h0: catodo_esperado = 7'h40;
                4'h1: catodo_esperado = 7'h67;
                4'h2: catodo_esperado = 7'h30;
                4'h3: catodo_esperado = 7'h21;

                4'h4: catodo_esperado = 7'h07;
                4'h5: catodo_esperado = 7'h09;
                4'h6: catodo_esperado = 7'h08;
                4'h7: catodo_esperado = 7'h63;

                4'h8: catodo_esperado = 7'h00;
                4'h9: catodo_esperado = 7'h01;
                4'hA: catodo_esperado = 7'h02;
                4'hB: catodo_esperado = 7'h0C;

                4'hC: catodo_esperado = 7'h58;
                4'hD: catodo_esperado = 7'h24;
                4'hE: catodo_esperado = 7'h18;
                4'hF: catodo_esperado = 7'h1A;

                default:
                    catodo_esperado = 7'h7F;

            endcase

        end

    endfunction


    // ============================================================
    // VARIABLES PARA EL TEST
    // ============================================================

    integer d;
    integer e1;
    integer e2;

    integer total_pruebas;
    integer errores;

    logic ok;
    logic [7:0] codigo_ref;


    // ============================================================
    // TEST PRINCIPAL
    // ============================================================

    initial begin

        total_pruebas = 0;
        errores       = 0;

        datos         = 4'h0;

        error_pos1    = 3'b000;
        error_pos2    = 3'b000;

        inyectar_p0   = 1'b0;

        #2;


        // ========================================================
        // PRUEBA 1
        // 16 DATOS POSIBLES SIN ERRORES
        // ========================================================

        $display("");
        $display("========================================");
        $display("PRUEBA 1: DATOS SIN ERROR");
        $display("========================================");

        for (d = 0; d < 16; d = d + 1) begin

            datos       = d;
            error_pos1  = 3'b000;
            error_pos2  = 3'b000;
            inyectar_p0 = 1'b0;

            #2;

            ok =
                (tx === codigo_esperado(datos)) &&
                (datos_rx === datos) &&
                (sindrome === 3'b000) &&
                (paridad_error === 1'b0) &&
                (sin_error === 1'b1) &&
                (corregir === 1'b0) &&
                (error_p0 === 1'b0) &&
                (ded === 1'b0) &&
                (catodo_tx === catodo_esperado(datos));

            total_pruebas = total_pruebas + 1;

            if (!ok) begin

                errores = errores + 1;

                $display(
                    "FALLO SIN ERROR: dato=%h tx=%h rx=%h datos_rx=%h S=%b",
                    datos,
                    tx,
                    rx,
                    datos_rx,
                    sindrome
                );

            end

        end


        // ========================================================
        // PRUEBA 2
        // UN ERROR EN CADA POSICIÓN HAMMING 1-7
        // ========================================================

        $display("");
        $display("========================================");
        $display("PRUEBA 2: CORRECCION DE UN ERROR SEC");
        $display("========================================");

        for (d = 0; d < 16; d = d + 1) begin

            for (e1 = 1; e1 <= 7; e1 = e1 + 1) begin

                datos       = d;
                error_pos1  = e1;
                error_pos2  = 3'b000;
                inyectar_p0 = 1'b0;

                #2;
                codigo_ref = codigo_esperado(datos);

                ok =
                    (sindrome === error_pos1) &&
                    (paridad_error === 1'b1) &&
                    (corregir === 1'b1) &&
                    (error_p0 === 1'b0) &&
                    (ded === 1'b0) &&
                    (datos_rx === datos) &&
                    (palabra_corregida === codigo_ref[6:0]) &&
                    (catodo_tx === catodo_esperado(datos));

                total_pruebas = total_pruebas + 1;

                if (!ok) begin

                    errores = errores + 1;

                    $display(
                        "FALLO SEC: dato=%h posicion=%0d rx=%h S=%b datos_rx=%h",
                        datos,
                        e1,
                        rx,
                        sindrome,
                        datos_rx
                    );

                end

            end

        end


        // ========================================================
        // PRUEBA 3
        // ERROR ÚNICAMENTE EN P0
        // ========================================================

        $display("");
        $display("========================================");
        $display("PRUEBA 3: ERROR EN PARIDAD GLOBAL P0");
        $display("========================================");

        for (d = 0; d < 16; d = d + 1) begin

            datos       = d;
            error_pos1  = 3'b000;
            error_pos2  = 3'b000;
            inyectar_p0 = 1'b1;

            #2;

            ok =
                (sindrome === 3'b000) &&
                (paridad_error === 1'b1) &&
                (sin_error === 1'b0) &&
                (corregir === 1'b0) &&
                (error_p0 === 1'b1) &&
                (ded === 1'b0) &&
                (datos_rx === datos);

            total_pruebas = total_pruebas + 1;

            if (!ok) begin

                errores = errores + 1;

                $display(
                    "FALLO P0: dato=%h rx=%h S=%b datos_rx=%h",
                    datos,
                    rx,
                    sindrome,
                    datos_rx
                );

            end

        end


        // ========================================================
        // PRUEBA 4
        // DOS ERRORES ENTRE POSICIONES HAMMING 1-7
        // ========================================================

        $display("");
        $display("========================================");
        $display("PRUEBA 4: DETECCION DE DOS ERRORES DED");
        $display("========================================");

        inyectar_p0 = 1'b0;

        for (d = 0; d < 16; d = d + 1) begin

            for (e1 = 1; e1 <= 7; e1 = e1 + 1) begin

                for (e2 = e1 + 1; e2 <= 7; e2 = e2 + 1) begin

                    datos       = d;
                    error_pos1  = e1;
                    error_pos2  = e2;

                    #2;

                    ok =
                        (sindrome !== 3'b000) &&
                        (paridad_error === 1'b0) &&
                        (corregir === 1'b0) &&
                        (error_p0 === 1'b0) &&
                        (ded === 1'b1);

                    total_pruebas = total_pruebas + 1;

                    if (!ok) begin

                        errores = errores + 1;

                        $display(
                            "FALLO DED: dato=%h errores=%0d,%0d rx=%h S=%b",
                            datos,
                            e1,
                            e2,
                            rx,
                            sindrome
                        );

                    end

                end

            end

        end


        // ========================================================
        // PRUEBA 5
        // UN ERROR HAMMING + ERROR EN P0
        // TAMBIÉN SON DOS ERRORES
        // ========================================================

        $display("");
        $display("========================================");
        $display("PRUEBA 5: ERROR HAMMING + ERROR P0");
        $display("========================================");

        for (d = 0; d < 16; d = d + 1) begin

            for (e1 = 1; e1 <= 7; e1 = e1 + 1) begin

                datos       = d;
                error_pos1  = e1;
                error_pos2  = 3'b000;
                inyectar_p0 = 1'b1;

                #2;

                ok =
                    (sindrome !== 3'b000) &&
                    (paridad_error === 1'b0) &&
                    (corregir === 1'b0) &&
                    (ded === 1'b1);

                total_pruebas = total_pruebas + 1;

                if (!ok) begin

                    errores = errores + 1;

                    $display(
                        "FALLO DED+P0: dato=%h posicion=%0d rx=%h S=%b",
                        datos,
                        e1,
                        rx,
                        sindrome
                    );

                end

            end

        end


        // ========================================================
        // RESULTADO
        // ========================================================

        $display("");
        $display("========================================");
        $display("RESULTADO FINAL");
        $display("========================================");

        $display(
            "Total de pruebas ejecutadas = %0d",
            total_pruebas
        );

        $display(
            "Total de fallos = %0d",
            errores
        );

        if (errores == 0) begin

            $display("");
            $display("TODAS LAS PRUEBAS PASARON CORRECTAMENTE");
            $display("");

        end
        else begin

            $display("");
            $display("EXISTEN ERRORES EN EL DISENO");
            $display("");

        end

        #10;

        $finish;

    end


    // ============================================================
    // FORMAS DE ONDA
    // ============================================================

    initial begin

        $dumpfile("sistema_tb.vcd");
        $dumpvars(0, sistema_tb);

    end


endmodule
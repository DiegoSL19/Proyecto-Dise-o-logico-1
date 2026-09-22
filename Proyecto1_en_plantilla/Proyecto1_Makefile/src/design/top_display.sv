module top_display (

    input  [3:0] datos_pi,

    input        p1_pi,
    input        p2_pi,
    input        p4_pi,
    input        p0_pi,

    input  [2:0] error1_pi,
    input  [2:0] error2_pi,

    input        modo_rx_pi,

    output [6:0] catodo_po,
    output [6:0] catodo_rx_po,
    output [3:0] paridad_led_po,

    // Los mismos 8 pines sirven para transmitir o recibir
    inout wire [7:0] tx_po
);


    // =====================================================
    // MODO DE OPERACION
    // =====================================================
    // 1 = TRANSMISOR
    // 0 = RECEPTOR EXTERNO
    //
    // Para cambiar de TX a RX solamente cambia esta línea
    // y vuelve a hacer Build + Program.
    // =====================================================
    localparam MODO_TX = 1'b1;


    // =====================================================
    // Señales internas
    // =====================================================
    wire [7:0] codigo_correcto;
    wire [7:0] tx_interno;

    wire [7:0] codigo_rx;

    wire [2:0] sindrome_rx;
    wire       paridad_error_rx;
    wire       error_simple_rx;
    wire       error_doble_rx;

    wire [7:0] codigo_corregido_rx;
    wire [3:0] datos_corregidos_rx;

    wire [3:0] dato_display_rx;


    // =====================================================
    // Palabra Hamming SEC-DED
    //
    // bit 0 = P1
    // bit 1 = P2
    // bit 2 = D0
    // bit 3 = P4
    // bit 4 = D1
    // bit 5 = D2
    // bit 6 = D3
    // bit 7 = P0
    // =====================================================
    assign codigo_correcto[0] = p1_pi;
    assign codigo_correcto[1] = p2_pi;
    assign codigo_correcto[2] = datos_pi[0];
    assign codigo_correcto[3] = p4_pi;
    assign codigo_correcto[4] = datos_pi[1];
    assign codigo_correcto[5] = datos_pi[2];
    assign codigo_correcto[6] = datos_pi[3];
    assign codigo_correcto[7] = p0_pi;


    // =====================================================
    // Generador de errores
    // =====================================================
    generador_error u_error (
        .codigo_pi  (codigo_correcto),
        .error1_pi  (error1_pi),
        .error2_pi  (error2_pi),
        .codigo_po  (tx_interno)
    );


    // =====================================================
    // BUS EXTERNO TX / RX
    // =====================================================
    //
    // MODO_TX = 1:
    // tx_interno sale por tx_po.
    //
    // MODO_TX = 0:
    // la FPGA deja los pines en alta impedancia (Z)
    // para que otra FPGA pueda manejarlos.
    // =====================================================
    assign tx_po = MODO_TX ? tx_interno : 8'bzzzzzzzz;


    // =====================================================
    // Selección de la entrada del receptor
    // =====================================================
    //
    // En modo TX usamos loopback interno para poder seguir
    // comprobando nuestro propio transmisor/receptor.
    //
    // En modo RX tomamos los datos desde los pines externos.
    // =====================================================
    assign codigo_rx = MODO_TX ? tx_interno : tx_po;


    // =====================================================
    // Receptor SEC-DED
    // =====================================================
    receptor_core u_receptor (
        .codigo_rx_pi          (codigo_rx),

        .sindrome_po           (sindrome_rx),
        .paridad_error_po      (paridad_error_rx),
        .error_simple_po       (error_simple_rx),
        .error_doble_po        (error_doble_rx),

        .codigo_corregido_po   (codigo_corregido_rx),
        .datos_corregidos_po   (datos_corregidos_rx)
    );


    // =====================================================
    // Display del transmisor
    // =====================================================
    seven_segment u_display (
        .datos_pi   (datos_pi),
        .catodo_po  (catodo_po)
    );


    // =====================================================
    // Selector del display del receptor
    //
    // modo_rx_pi = 0 -> dato corregido
    // modo_rx_pi = 1 -> síndrome
    // =====================================================
    assign dato_display_rx =
        modo_rx_pi ? {1'b0, sindrome_rx}
                   : datos_corregidos_rx;


    // =====================================================
    // Display del receptor
    // =====================================================
    seven_segment u_display_rx (
        .datos_pi   (dato_display_rx),
        .catodo_po  (catodo_rx_po)
    );


    // =====================================================
    // LEDs internos de diagnóstico
    // LEDs activos en bajo
    // =====================================================
    assign paridad_led_po[0] = ~sindrome_rx[0];
    assign paridad_led_po[1] = ~sindrome_rx[1];
    assign paridad_led_po[2] = ~sindrome_rx[2];
    assign paridad_led_po[3] = ~error_doble_rx;


endmodule
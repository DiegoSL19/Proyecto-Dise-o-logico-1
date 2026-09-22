module seven_segment (
    input  [3:0] datos_pi,
    output [6:0] catodo_po
);

    wire x3;
    wire x2;
    wire x1;
    wire x0;

    assign x3 = datos_pi[3];
    assign x2 = datos_pi[2];
    assign x1 = datos_pi[1];
    assign x0 = datos_pi[0];

    // Segmento a -> catodo_po[2]
    assign catodo_po[2] =
        ( x3 &  x2 &  x0 & ~x1) |
        ( x3 &  x1 &  x0 & ~x2) |
        ( x2 & ~x3 & ~x1 & ~x0) |
        ( x0 & ~x3 & ~x2 & ~x1);

    // Segmento b -> catodo_po[3]
    assign catodo_po[3] =
        ( x3 &  x1 &  x0) |
        ( x3 &  x2 & ~x0) |
        ( x2 &  x1 & ~x0) |
        ( x2 &  x0 & ~x3 & ~x1);

    // Segmento c -> catodo_po[4]
    assign catodo_po[4] =
        ( x3 &  x2 &  x1) |
        ( x3 &  x2 & ~x0) |
        ( x1 & ~x3 & ~x2 & ~x0);

    // Segmento d -> catodo_po[1]
    assign catodo_po[1] =
        ( x2 &  x1 &  x0) |
        ( x3 &  x1 & ~x2 & ~x0) |
        ( x2 & ~x3 & ~x1 & ~x0) |
        ( x0 & ~x3 & ~x2 & ~x1);

    // Segmento e -> catodo_po[0]
    assign catodo_po[0] =
        ( x0 & ~x3) |
        ( x2 & ~x3 & ~x1) |
        ( x0 & ~x2 & ~x1);

    // Segmento f -> catodo_po[5]
    assign catodo_po[5] =
        ( x1 &  x0 & ~x3) |
        ( x1 & ~x3 & ~x2) |
        ( x0 & ~x3 & ~x2) |
        ( x3 &  x2 &  x0 & ~x1);

    // Segmento g -> catodo_po[6]
    assign catodo_po[6] =
        ( x2 &  x1 &  x0 & ~x3) |
        (~x3 & ~x2 & ~x1) |
        ( x3 &  x2 & ~x1 & ~x0);

endmodule
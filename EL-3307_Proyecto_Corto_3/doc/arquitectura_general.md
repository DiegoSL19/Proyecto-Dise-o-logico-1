# Arquitectura de la máquina expendedora

El Proyecto Corto 3 implementa una máquina expendedora de tres productos en la Tang Nano 9K. Una solicitud selecciona producto y cantidad de monedas; la máquina consulta existencias, calcula crédito menos precio y decide entre entregar o devolver. El vuelto de una entrega se muestra en decimal en cuatro dígitos de siete segmentos.

## Plataforma y entradas

Todo el diseño utiliza el oscilador de 27 MHz. Los temporizadores y el refresco usan contadores y habilitaciones, sin relojes derivados.

| Entrada del top | Función |
|---|---|
| clk | Reloj de 27 MHz |
| reset_n | Reset global mediante S1 |
| restart_n | Reiniciar una transacción terminada, conservando inventario |
| start_n | Confirmar producto y cantidad de monedas |
| product_sw[1:0] | Producto A=00, B=01, C=10; código 11 inválido |
| coins_sw[2:0] | Cantidad binaria de cero a siete monedas de 100 |

Los contactos físicos son activos bajos: abiertos entregan uno eléctrico y cerrados a GND entregan cero. Después de sincronizar, el wrapper invierte esos niveles para que cerrado signifique uno lógico.

Los siete contactos de datos pasan por sincronización y filtros independientes de antirrebote. La guarda inicial permite llenar esos registros; una pulsación sostenida durante reset debe soltarse antes de habilitar un evento. Los cinco bits DIP deben estar estables antes de aceptar START.

Producto e importe se retienen conjuntamente antes de solicitar la transacción al core. El wrapper reserva transaction_busy y descarta nuevas pulsaciones mientras está ocupado o permanece visible una devolución.

## Productos y ruta de datos

| Producto | Código | Precio | Inventario inicial |
|---|---|---:|---:|
| A | 00 | 150 | 3 |
| B | 01 | 275 | 3 |
| C | 10 | 400 | 3 |

Los registros monetarios tienen diez bits. La interfaz física produce de 0 a 700 colones y el vuelto físico máximo es 550. El inventario usa dos bits por producto.

La ruta de datos conserva selección, crédito capturado, precio, crédito de operación y vuelto. El restador reutilizado entrega magnitud, signo y un pulso result_valid. La autorización utiliza el signo de crédito menos precio, junto con selección válida y disponibilidad.

## Unidad de control

vending_fsm tiene nueve estados One-Hot, definidos mediante typedef enum. Un bloque always_ff registra el estado, otro always_comb calcula transiciones y otro always_comb genera habilitaciones.

La secuencia disponible es captura, revisión, carga de operandos, lanzamiento de resta, consumo del resultado, entrega y espera de RESTART. Las cargas, la resta y el consumo ocupan flancos distintos. La FSM no ejecuta operaciones de la ruta de datos.

Si el producto está agotado no se calcula ni se decrementa. Si el pago es insuficiente, el resultado negativo inicia devolución automática. Ambas rutas limpian datos temporales y regresan a reposo sin restaurar inventarios.

RESTART se acepta después de una entrega y conserva existencias. S1 es independiente: restaura tres unidades de cada producto y reinicia control, datos y temporizadores.

## Indicadores y display

| Salida | Comportamiento |
|---|---|
| delivery_led_n[2:0] | Un LED activo bajo por entrega A/B/C; se mantiene hasta RESTART |
| empty_led_n[2:0] | Un LED activo bajo por producto agotado; persiste hasta reset global |
| refund_led | LED activo alto de devolución durante dos segundos |
| an[3:0] | Selección multiplexada de los cuatro dígitos |
| sseg[7:0] | Punto decimal en bit 7 y segmentos a, b, c, d, e, f, g en bits 6 a 0 |

change_reg alimenta vending_display. El registro de entrega habilita la presentación hasta RESTART; en reposo, reset y devolución se apagan todos los segmentos y dígitos. Se conservan ceros iniciales: 0050, 0025 y 0000 son ejemplos de vuelto.

vending_display reutiliza bcd_converter, rom_reg, tick_generator y disp_hex_mux del Proyecto Corto 2. Separa millares y resto de 0 a 999; para restos desde 500 consulta la ROM con resto menos 500 y añade cinco a las centenas. Solo requiere direcciones 0 a 499 de una ROM de 512 entradas, conservando los datos originales y representando todo el rango de diez bits.

Con DISPLAY_DIV=6750 se genera un pulso de habilitación cada 6750 ciclos: 4000 posiciones de dígito por segundo y 1000 refrescos completos de cuatro dígitos. El multiplexor avanza con ese pulso y conserva el reloj de 27 MHz.

SEGMENTS_ACTIVE_LOW y DIGITS_ACTIVE_LOW adaptan la polaridad. Sus valores predeterminados son cero, siguiendo la interfaz de salida usada en el Proyecto Corto 2. Esto no identifica por sí solo el tipo eléctrico del display ni su circuito de manejo. Las conexiones y comprobaciones de pines se documentan en [preparacion_tangnano9k.md](preparacion_tangnano9k.md).

## Decisiones y contradicciones del enunciado

La entrada descrita cuenta monedas de 100, mientras que los ejemplos de verificación incluyen pagos de 150 y 125 usando otras denominaciones. El top conserva la interfaz de cantidades; esos importes se inyectan directamente al core para verificar sus resultados numéricos.

La sección aritmética exige devolver cuando hay faltante; otro ejemplo menciona cancelar sin definir una entrada. El sistema implementa devolución automática y no incorpora un pulsador adicional.

El enunciado menciona temporizadores de dos segundos sin asignar su uso exacto. La implementación usa ese intervalo para el LED de devolución; la entrega y el vuelto permanecen visibles hasta RESTART.

La sección de entradas menciona un teclado en su título, pero describe dos DIP y dos pulsadores. La interfaz implementada sigue esa descripción funcional.

## Documentación y verificación

El [diagrama de bloques](diagrama_bloques.md), el [diagrama de estados](diagrama_estados_fsm.md), las [transiciones](tabla_transiciones_fsm.md), las [salidas](tabla_salidas_control_fsm.md) y las [ecuaciones](ecuaciones_fsm.md) describen la arquitectura implementada.

La verificación debe distinguir bancos RTL, implementación con análisis estático, simulaciones con retardos y pruebas físicas. Un resultado de una etapa no sustituye a las demás ni se declara aprobado antes de ejecutarlo.

Referencias: enunciado del Proyecto Corto 3 incluido en este directorio; Harris y Harris, Digital Design and Computer Architecture; documentación oficial de la Tang Nano 9K y de Gowin citada en la preparación física.

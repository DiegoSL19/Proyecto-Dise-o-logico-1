# Validación de módulos reutilizables

Este documento conserva el registro de pruebas unitarias originales del Proyecto Corto 2 y describe su uso en el Proyecto Corto 3. Una prueba aislada no demuestra que el sistema completo esté conectado o que sus salidas físicas sean correctas.

## Registro histórico de pruebas unitarias

Los siguientes resultados corresponden a las simulaciones originales registradas antes de integrar el display de la máquina expendedora:

| Módulo | Comprobaciones | Errores |
|---|---:|---:|
| synchronizer | 18 | 0 |
| debouncer | 72 | 0 |
| tick_generator | 42 | 0 |
| subtractor | 17 | 0 |
| bcd_converter | 12 | 0 |
| disp_hex_mux | 143 | 0 |
| Total histórico | 304 | 0 |

Este cuadro conserva su carácter histórico. La corrida nueva del 17/11/2026 volvió a aprobar los 16 bancos RTL de PC2, 967 comprobaciones y cero errores. La [auditoría](auditoria_y_verificacion.md) registra por separado las ejecuciones unitarias, de integración y de netlists, junto con sus limitaciones.

## Contratos y limitaciones

| Módulo | Contrato relevante | Verificación y límites |
|---|---|---|
| synchronizer | Dos etapas de cuatro bits, reset síncrono activo alto, reposo 1111 | Comprobar latencia y reset; RTL no modela metastabilidad física |
| debouncer | Contador de estabilidad, reset síncrono activo bajo | Las pruebas originales usan N=4; hardware usa N=21 |
| tick_generator | Pulsos de habilitación de un ciclo desde clk | Los divisores reducidos verifican período y ancho; no generan otro reloj |
| subtractor | Operandos de diez bits; magnitud, signo y result_valid registrados | Interpretar signo/magnitud solo con validez nueva y conservar orden crédito menos precio |
| bcd_converter | ROM combinacional, tres dígitos BCD | Resolver rom_reg y bcdtable.txt; se cubrieron doce entradas dirigidas |
| disp_hex_mux | Selección de cuatro dígitos, segmentos y puntos decimales | La codificación interna es activa baja; comprobar orden, patrones y selección |
| rom_reg | Lectura combinacional inicializada mediante readmemh | Su verificación original está incluida en bcd_converter; la memoria debe existir al simular y sintetizar |

Las pruebas de subtractor cubrieron restas positivas, negativas e iguales, retención sin calculate y prioridad de reset. No sustituyen la verificación de cargas, validez y consumo de resultados del core.

La ROM original convierte 0 a 999 en tres dígitos y produce 000 para su entrada 1000. vending_display conserva esa tabla y separa primero el millar. Para restos desde 500 resta 500 antes de consultar la ROM y añade cinco a las centenas. El conversor se instancia con N=9, M=12: direcciones usadas 0–499, profundidad 512. El rango completo 0–1023 y ambas polaridades del display pasaron 50 476 comprobaciones. rom_reg ahora delimita explícitamente la lectura al rango declarado; en las instancias originales de diez bits ese rango sigue siendo 0–1023.

El multiplexor conserva su modo original con USE_TICK=0. La integración utiliza USE_TICK=1 y N=2, avanzando únicamente con tick_display. Sus pruebas originales deben seguir pasando y las pruebas nuevas deben cubrir el modo habilitado.

## Integración que debe verificarse

La ruta conectada es change_reg, vending_display, conversión BCD, multiplexor y salidas an/sseg. El registro de entrega habilita la presentación hasta RESTART. Reposo, reset y devolución producen blanco total.

La integración emplea DISPLAY_DIV=6750, equivalente a 4000 posiciones de dígito por segundo y 1000 cuadros completos a 27 MHz. La simulación puede reducir el divisor para observar varios barridos sin cambiar la estructura del reloj.

Las comprobaciones deben observar las salidas públicas del display y cubrir:

- A con 200: entrega y 0050.
- B con 300: entrega y 0025.
- C con 400: entrega y 0000.
- C con 300: devolución de 300, sin decremento ni presentación de vuelto.
- Producto agotado: devolución y conservación del inventario.
- Cuatro posiciones, orden decimal, ceros iniciales y puntos apagados.
- Valores de límite de dígito y rango completo del wrapper de diez bits.
- Ambas polaridades configurables de segmentos y dígitos.
- Blanco por reset, RESTART, reposo y devolución.
- Retención del vuelto y del producto frente a cambios de DIP durante ocupación.

## Casos numéricos del enunciado

A con 150 y C con 125 se inyectan directamente en los bancos de FSM/core. La entrada física representa cantidades de monedas de 100 y no admite esos importes. El modelo de FSM transforma los valores en condiciones de suficiencia; el banco de vending_system comprueba la aritmética, la captura y los inventarios reales.

Para C125, el faltante es 275 y el importe devuelto es 125. La devolución es automática según la sección aritmética; el diseño no incorpora una entrada CANCEL no definida por la interfaz.

## Evidencias y alcance

Una corrida RTL debe guardar el listado de fuentes, sus hashes y los resultados de cada banco. La implementación de Gowin debe reconstruirse con el display y sus dependencias para que el vuelto sea observable en las salidas.

Síntesis, colocación/ruteo y análisis estático no equivalen a simulaciones con retardos ni a una prueba de la tarjeta. El enunciado también solicita simulaciones post-síntesis y post-ruteo; su estado debe registrarse según las ejecuciones reales. No deben declararse aprobaciones nuevas antes de disponer de sus logs.

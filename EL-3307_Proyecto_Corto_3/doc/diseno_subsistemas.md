# Diseño de subsistemas

La arquitectura separa acondicionamiento físico, control, ruta de datos y presentación. vending_top reúne estos bloques; vending_system conserva la FSM, los registros y la aritmética de la transacción.

## Interfaces funcionales

| Subsistema | Entradas | Salidas y función |
|---|---|---|
| Sincronización y antirrebote | Dos pulsadores y cinco bits DIP activos bajos | Señales lógicas estables |
| Control de pulsación | START y RESTART filtrados | Un evento por pulsación, con rearme al soltar |
| Captura de solicitud | Producto, monedas y evento START | product_held, credit_held, request_event y reserva de ocupación |
| FSM | Solicitud, selección válida, disponibilidad, validez/signo/autorización y RESTART | Habilitaciones de captura, cargas, resta, entrega, devolución y limpieza |
| Ruta de datos | Datos retenidos y habilitaciones | Producto, precio, crédito, vuelto, existencias y condiciones de compra |
| Presentación de LED | Decrementos, agotamiento y devolución | Indicaciones con duración visible |
| Display decimal | change_reg y habilitación de entrega | Cuatro dígitos multiplexados y segmentos |
| Temporización | Reloj de 27 MHz, reset y habilitaciones | Pulso de refresco y fin de devolución |

## Acondicionamiento y captura

Dos instancias de synchronizer transportan siete señales; la entrada adicional se fija en alto. Después de sincronizar se invierten los contactos físicos activos bajos. Cada señal utiliza un debouncer independiente.

DEBOUNCE_N=21 produce una ventana de 1048576 cuentas, aproximadamente 38,836 ms. Las guardas de arranque y estabilidad añaden margen para los registros. S1 se adapta mediante afirmación asíncrona y liberación sincronizada del reset interno.

La habilitación inicial impide interpretar como una pulsación nueva un botón sostenido a través del reset. Los detectores generan eventos de un ciclo y se rearman después de observar el botón suelto.

START se acepta con DIP estables, código de producto válido, sin transacción ocupada y sin indicación de devolución. En ese flanco se retienen producto e importe y se reserva transaction_busy. La solicitud al core se emite después de retener los datos. Las pulsaciones rechazadas se descartan.

Los tres bits de monedas representan cantidades de 0 a 7; el importe retenido es cantidad por 100. Producto y crédito permanecen estables durante su uso por el core.

## Registros y operaciones

| Registro | Contenido | Actualización |
|---|---|---|
| product_held | Solicitud física aceptada | START aceptado en el wrapper |
| credit_held | Importe físico de 0 a 700 | Misma captura que product_held |
| credit_captured | Copia del importe de la solicitud | capture_credit en REPOSO |
| product_sel_reg | Producto de la operación | load_selection |
| price_reg | Precio 150, 275 o 400 | load_price |
| credit_reg | Operando monetario | load_credit, desde credit_captured |
| magnitude y negative | Resultado absoluto y signo de crédito menos precio | calculate_balance |
| change_reg | Vuelto autorizado | load_change |
| inventory_A/B/C | Existencias de 0 a 3 | Reset global o decremento correspondiente |

Los registros monetarios tienen diez bits y los de inventario dos. La resta extiende operandos para obtener el signo correctamente. purchase_decision combina selección válida, inventario y resultado nuevo; la suficiencia procede del signo.

## Control y secuencia

vending_fsm utiliza nueve estados One-Hot y tres bloques: registro, transición y salidas. Las cargas de precio/crédito se consumen en E0, la resta en E1 y el resultado en E2. El decremento del producto autorizado dura un ciclo.

Producto agotado inicia devolución sin cargar operandos ni restar. Pago insuficiente inicia devolución al consumir el resultado negativo. DEVOLUCION y RETORNO_REPOSO duran un ciclo cada uno; la limpieza no modifica inventarios.

RESTART solo se acepta en ESPERA_RESTART y borra datos temporales. El reset global restaura las tres unidades de cada producto. El wrapper libera la reserva al observar clear_transaction.

## Presentación

delivery_saved registra el decremento elegido y conserva el LED de entrega hasta limpiar la transacción. Los LED de agotado siguen el nivel de inventario cero.

refund_active rearma timer_2s y activa un registro visual. REFUND_CYCLES=54000000 produce dos segundos de LED de devolución. Esa presentación no se borra con clear_transaction y bloquea otras solicitudes hasta terminar.

change_reg está conectado al display. display_enable depende del registro de entrega, por lo que el vuelto permanece visible hasta RESTART. En los demás estados el display queda totalmente en blanco.

vending_display separa millares y resto decimal. Para restos desde 500 resta 500 antes de consultar bcd_converter con N=9, M=12 y añade cinco a las centenas. La ROM de 512 entradas solo recibe direcciones 0–499; sus datos coinciden con el prefijo de la tabla original. disp_hex_mux utiliza N=2, USE_TICK=1 y el pulso de tick_generator para recorrer los cuatro dígitos. Cada pulso habilita registros del único reloj de 27 MHz.

DISPLAY_DIV=6750 da 4000 posiciones por segundo y 1000 cuadros completos por segundo. Las salidas an y sseg adaptan sus polaridades mediante parámetros; los ceros iniciales permanecen visibles y los puntos decimales apagados.

## Reutilización y archivos de memoria

Los módulos synchronizer, debouncer, subtractor, bcd_converter, rom_reg, tick_generator y disp_hex_mux se copiaron sin cambios de lógica a src/design/reused, junto con bcdtable.txt. Su origen es el Proyecto Corto 2; el PC3 compila exclusivamente sus copias locales. El modo predeterminado USE_TICK=0 del multiplexor conserva su avance original; el Proyecto Corto 3 habilita su modo de pulso.

La tabla local src/design/reused/bcdtable.txt conserva las 1024 entradas originales. Los flujos de simulación y síntesis preparan su prefijo de 512 entradas en el directorio de ejecución esperado por ../design/bcdtable.txt. Así se conserva la interfaz de los módulos copiados y se evitan archivos externos y avisos por exceso de palabras. El wrapper no modifica los datos originales de la tabla.

La conversión original produce tres dígitos y la entrada 1000 aislada no representa cuatro dígitos. vending_display evita esa limitación: resta 1000 para formar el resto y entrega el millar por separado. El rango completo de diez bits puede mostrarse sin cambiar la ROM.

## Escenarios de verificación

Se requieren pagos A200 con vuelto50, B300 con vuelto25, C400 con vuelto0 y C300 con devolución300. Tres entregas de A agotan su inventario; un cuarto intento devuelve sin decrementar.

Los importes A150 y C125 del PDF se verifican directamente en el core, porque la entrada física de monedas de 100 no los representa. La devolución conserva el importe completo, no la magnitud del faltante.

Las pruebas de display deben observar an/sseg, los cuatro dígitos, polaridades, puntos decimales, refresco y blanco por reset, RESTART o devolución. También deben verificar que el vuelto permanece visible aunque cambien los DIP durante la espera.

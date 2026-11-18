# Salidas de control de la FSM

Las habilitaciones combinacionales se consumen en el siguiente flanco positivo de 27 MHz. Durante reset permanecen en cero. La clasificación Moore/Mealy describe operación normal: una condición recibida de la ruta de datos también es entrada de la FSM.

| Señal | Estado | Condición adicional | Tipo | Destino |
|---|---|---|---|---|
| capture_credit | REPOSO | request_event | Mealy | credit_captured |
| load_selection | CAPTURA_SOLICITUD | Ninguna | Moore | Producto seleccionado |
| load_price | CARGA_Y_REVISION | selection_valid y selected_available | Mealy | Operando de precio |
| load_credit | CARGA_Y_REVISION | selection_valid y selected_available | Mealy | Operando de crédito, desde credit_captured |
| calculate_balance | LANZAR_CALCULO | Ninguna | Moore | calculate del restador |
| load_change | CALCULO_SALDO | result_valid y purchase_authorized | Mealy | change_reg, desde magnitude |
| decrement_A | ENTREGA | selection_valid y producto 00 | Mealy | Inventario A y registro visual |
| decrement_B | ENTREGA | selection_valid y producto 01 | Mealy | Inventario B y registro visual |
| decrement_C | ENTREGA | selection_valid y producto 10 | Mealy | Inventario C y registro visual |
| refund_active | DEVOLUCION | Ninguna | Moore | Indicación y rearme del temporizador |
| clear_transaction | ESPERA_RESTART o RETORNO_REPOSO | restart_event en ESPERA_RESTART; siempre en RETORNO_REPOSO | Mixta | Limpieza temporal |

load_price/load_credit no coinciden con calculate_balance. El lanzamiento ocupa un ciclo y se consume su resultado en el siguiente. load_change solo captura un resultado autorizado y nuevo.

## Acciones e indicadores

Los decrementos duran un ciclo y son mutuamente excluyentes. El inventario se actualiza una vez; delivery_saved registra el producto para mantener su LED hasta la limpieza de la transacción.

empty_A/B/C son niveles del inventario. Permanecen activos al llegar a cero, también después de RESTART. El reset global restaura existencias y elimina el agotamiento.

refund_active dura un ciclo. El wrapper mantiene refund_visible y usa timer_2s para indicar dos segundos de devolución. clear_transaction no borra esa presentación; el fin del temporizador apaga el LED.

## Vuelto y cuatro dígitos

change_reg almacena la magnitud de una resta autorizada. No contiene el faltante ni el crédito de devolución. Permanece estable durante ESPERA_RESTART y alimenta vending_display.

delivery_saved habilita el display. Se muestran cuatro dígitos, incluidos ceros iniciales: 0050, 0025 y 0000. El display queda totalmente en blanco en reposo, reset, después de RESTART y durante devolución.

El selector avanza con una habilitación derivada del único reloj. Las polaridades físicas de segmentos y dígitos son parametrizables.

## Reset y RESTART

El reset global inicializa estado, importes y temporizadores y restaura inventarios a tres. RESTART solo se acepta en la espera final de una entrega: limpia solicitud y vuelto sin restaurar existencias. RETORNO_REPOSO realiza esa limpieza temporal después de devolver.

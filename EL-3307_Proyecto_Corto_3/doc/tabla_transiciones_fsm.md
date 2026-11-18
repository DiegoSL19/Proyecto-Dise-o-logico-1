# Tabla de transiciones de la FSM

La tabla corresponde a vending_fsm.sv. Todos los cambios ocurren en el flanco positivo del único reloj de 27 MHz.

| Estado actual | Condición | Estado siguiente | Acción durante el estado actual |
|---|---|---|---|
| REPOSO | request_event=0 | REPOSO | Sin cargas |
| REPOSO | request_event=1 | CAPTURA_SOLICITUD | capture_credit=1 |
| CAPTURA_SOLICITUD | Siempre | CARGA_Y_REVISION | load_selection=1 |
| CARGA_Y_REVISION | selection_valid=0 | CARGA_Y_REVISION | Sin cargas ni cálculo |
| CARGA_Y_REVISION | selection_valid=1 y selected_available=1 | LANZAR_CALCULO | load_price=1, load_credit=1 |
| CARGA_Y_REVISION | selection_valid=1 y selected_available=0 | DEVOLUCION | Sin cargas, cálculo o decrementos |
| LANZAR_CALCULO | Siempre | CALCULO_SALDO | calculate_balance=1 |
| CALCULO_SALDO | result_valid=1 y purchase_authorized=1 | ENTREGA | load_change=1 |
| CALCULO_SALDO | result_valid=1, purchase_authorized=0 y negative=1 | DEVOLUCION | Sin carga de vuelto |
| CALCULO_SALDO | Ninguna condición anterior | CALCULO_SALDO | Esperar sin repetir cálculo |
| ENTREGA | Siempre | ESPERA_RESTART | Un decremento del producto capturado si selection_valid=1 |
| ESPERA_RESTART | restart_event=0 | ESPERA_RESTART | Conservar transacción |
| ESPERA_RESTART | restart_event=1 | REPOSO | clear_transaction=1 |
| DEVOLUCION | Siempre | RETORNO_REPOSO | refund_active=1 |
| RETORNO_REPOSO | Siempre | REPOSO | clear_transaction=1 |
| Estado no reconocido | Sin reset | REPOSO | Salidas inactivas |
| Cualquier estado | reset=1 | REPOSO | Salidas inactivas |

Reset tiene prioridad global. En CALCULO_SALDO, la autorización tiene prioridad sobre la condición negativa, conservando el comportamiento original.

## Flancos de la ruta de datos

| Flanco | Estado antes del flanco | Operación |
|---|---|---|
| Aceptación | REPOSO | Capturar credit_in con request_event |
| Captura de producto | CAPTURA_SOLICITUD | Registrar product_sel_in |
| E0 | CARGA_Y_REVISION | Registrar precio y crédito con selección válida y disponibilidad |
| E1 | LANZAR_CALCULO | Registrar magnitud, signo y validez de la resta |
| E2 | CALCULO_SALDO | Consumir validez y registrar vuelto si hay autorización |
| Entrega | ENTREGA | Reducir una unidad del inventario seleccionado |
| Reinicio o retorno | ESPERA_RESTART con evento, o RETORNO_REPOSO | Limpiar datos temporales y conservar inventarios |

Producto y crédito proceden de los registros retenidos del wrapper. Los DIP vivos no sustituyen datos de la transacción en curso.

## Acciones del wrapper

START se acepta con entradas listas, producto válido, sin transacción reservada y sin LED de devolución. Una pulsación rechazada no queda encolada.

El decremento carga el LED de entrega retenido y habilita el display de vuelto. RESTART aceptado apaga esa presentación. refund_active inicia una indicación de dos segundos que sobrevive a la limpieza del core.

Los precios son A=150, B=275 y C=400; cada inventario comienza en tres. Los DIP representan cantidades de monedas de 100. Los ejemplos del PDF con otras denominaciones se prueban directamente en el core, conservando devolución automática ante faltante.

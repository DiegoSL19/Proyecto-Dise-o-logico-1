# Análisis de la FSM principal

vending_fsm.sv decide cuándo capturar una solicitud, cargar operandos, calcular, entregar o devolver. Los importes y los inventarios pertenecen a módulos separados de la ruta de datos.

## Organización y estados

La FSM conserva nueve estados One-Hot en un typedef enum logic [8:0]. Un always_ff registra el estado; un always_comb calcula el siguiente estado; otro always_comb genera las salidas. Todos usan el reloj de 27 MHz. El reset lógico es síncrono y activo alto; vending_top adapta el pulsador físico.

| Estado | Acción | Condición de salida |
|---|---|---|
| REPOSO | Capturar crédito con request_event | Solicitud nueva |
| CAPTURA_SOLICITUD | load_selection | Un ciclo |
| CARGA_Y_REVISION | Consultar selección e inventario; cargar operandos si hay disponibilidad | Selección válida |
| LANZAR_CALCULO | calculate_balance | Un ciclo |
| CALCULO_SALDO | Consumir result_valid; guardar vuelto si purchase_authorized | Resultado autorizado o negativo |
| ENTREGA | Decrementar el producto capturado | Un ciclo |
| ESPERA_RESTART | Conservar la transacción | restart_event |
| DEVOLUCION | refund_active | Un ciclo |
| RETORNO_REPOSO | clear_transaction | Un ciclo, regreso automático |

La lógica combinacional asigna valores predeterminados en todos los caminos. Durante reset las salidas permanecen inactivas y el estado de destino es REPOSO. Un código de estado no reconocido se recupera hacia REPOSO.

Una selección inválida conserva el core en CARGA_Y_REVISION. El wrapper rechaza el código 11 antes de enviar la solicitud, evitando esa espera en la operación física.

## Captura coherente

Producto y crédito se retienen conjuntamente en vending_top antes de enviar request_event. El core captura crédito al aceptar la solicitud en REPOSO y producto al salir de CAPTURA_SOLICITUD. Los registros del wrapper evitan mezclar configuraciones de los DIP.

transaction_busy se reserva al aceptar START y se libera con clear_transaction. Una pulsación durante ocupación o mientras se indica devolución se descarta; no queda encolada.

## Carga y cálculo

La orientación es crédito menos precio. Para una compra disponible:

| Flanco | Estado antes del flanco | Acción |
|---|---|---|
| E0 | CARGA_Y_REVISION | Registrar precio y crédito, sin calcular |
| E1 | LANZAR_CALCULO | Solicitar una resta; el restador registra magnitud, signo y result_valid |
| E2 | CALCULO_SALDO | Consumir el resultado; guardar vuelto y pasar a ENTREGA si está autorizado |

La FSM no consume en E1 el resultado que el restador registra en ese mismo flanco. Si result_valid está bajo, espera sin repetir la resta. La magnitud retenida después del pulso no autoriza otra compra.

## Entrega, devolución y reinicio

La compra autorizada reduce una unidad al salir de ENTREGA. El wrapper retiene el LED correspondiente y habilita el display de vuelto hasta RESTART. No se prolonga la habilitación de inventario.

Producto agotado devuelve sin cargar operandos ni solicitar una resta. Pago insuficiente devuelve después de consumir el resultado negativo. Ambas rutas emiten refund_active, limpian la transacción y vuelven automáticamente a REPOSO. El crédito completo está disponible durante DEVOLUCION y no debe confundirse con el faltante.

RESTART solo se acepta en ESPERA_RESTART. Limpia datos temporales y apaga la presentación sin modificar inventarios. El reset global restaura tres unidades por producto.

El wrapper mantiene el LED de devolución durante 54 millones de ciclos, dos segundos a 27 MHz, independientemente de clear_transaction. Durante ese intervalo no acepta otra compra.

## Display y verificación

change_reg conserva el vuelto autorizado durante la espera de RESTART. vending_display convierte ese valor a decimal y refresca cuatro dígitos con habilitaciones del único reloj. Muestra 0050, 0025 o 0000 durante una entrega; fuera de esa presentación queda en blanco.

Los bancos comprueban transiciones, One-Hot, separación de cargas y cálculo, pulsos únicos, agotamiento y conservación de inventarios. Los importes A=150 y C=125 se prueban directamente en el core: la interfaz física de cantidad de monedas de 100 no puede representarlos. Esta contradicción del enunciado no agrega una entrada CANCEL.

La corrida RTL del 17/11/2026 aprobó 285 comprobaciones de FSM y 516 del sistema. La [auditoría](auditoria_y_verificacion.md) distingue estos resultados de la simulación post-ruteo y del bloqueo post-síntesis.

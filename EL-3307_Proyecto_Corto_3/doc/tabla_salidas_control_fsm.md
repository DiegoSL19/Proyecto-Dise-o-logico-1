# Tabla preliminar de salidas de control de la FSM

## Alcance y convenciones

Esta tabla propone las salidas de control para los nueve estados activos de la FSM One-Hot descritos en el [análisis FSM](./analisis_fsm.md), el [diagrama de estados](./diagrama_estados_fsm.md), la [tabla de transiciones](./tabla_transiciones_fsm.md) y el [diseño preliminar de subsistemas](./diseno_subsistemas.md). Se basa además en el enunciado oficial del Proyecto Corto 3 y en el enfoque de Harris y Harris, *Digital Design and Computer Architecture, ARM Edition*: la unidad de control secuencia operaciones y la ruta de datos ejecuta las cargas y actualizaciones en los flancos del reloj.

Es una propuesta para revisión, no una especificación definitiva. Los nombres de señales son descriptivos. Se usa **Moore** para una salida determinada por el estado actual y **Mealy** para una salida que además depende de una condición o evento. Para los controles condicionados por registros de la ruta de datos, la clasificación Mealy indica esa dependencia explícita, aunque el dato provenga de un registro y no de un pin externo.

Salvo S1, las habilitaciones de esta tabla se entienden activas antes del flanco positivo en que el registro o módulo controlado acepta la operación. S1 es el reset global; su polaridad, sincronía y adaptación a los módulos reutilizables están pendientes. No se derivan ecuaciones ni se especifica SystemVerilog.

## Tabla de señales

| Señal | Estado que la activa | Condición adicional | Tipo | Registro o módulo controlado | Flanco o momento de la acción |
|---|---|---|---|---|---|
| `capture_request` | `CAPTURA_SOLICITUD` | Ninguna en la propuesta; toma la selección de producto y el importe desde entradas sincronizadas y acondicionadas. | Moore | Registros de producto seleccionado e importe/crédito capturado. | En el flanco positivo que termina `CAPTURA_SOLICITUD` y avanza a `CARGA_Y_REVISION`. Debe definirse si la captura ocurre al aceptar `START` o durante este estado, para evitar que cambios posteriores de los DIP produzcan una selección distinta. |
| `load_price` | `CARGA_Y_REVISION` | Ninguna; usa el producto previamente capturado. | Moore | `price_reg`, con el precio del producto seleccionado. | **E0:** en el flanco positivo al salir de `CARGA_Y_REVISION`. |
| `load_credit` | `CARGA_Y_REVISION` | Ninguna; usa el importe previamente capturado. | Moore | `credit_reg`, operando de crédito del restador. | **E0:** en el mismo flanco que `load_price`; `calculate_balance=0`. |
| `calculate_balance` | `LANZAR_CALCULO` | Estado propuesto de un ciclo; los operandos deben haber sido cargados y estar estables desde E0. | Moore | Entrada `calculate` del módulo restador reutilizado. | **E1:** el restador muestrea el pulso en el flanco positivo; registra `magnitude` y `negative` y activa `result_valid`. La señal solo dura un ciclo. |
| `load_change` | `CALCULO_SALDO` | `result_valid=1` y `negative=0`. Si `result_valid=0` o `negative=1`, permanece inactiva. | Mealy | `change_reg`, que captura `magnitude` del restador. | **E2:** en el flanco positivo que consume `result_valid`; en ese flanco la FSM transita a `ENTREGA`. |
| `decrement_stock_A` | `ENTREGA` | El producto almacenado en `selected_product_reg` es A. | Mealy | Registro `inventory_A_reg`. | Un único pulso durante el ciclo de `ENTREGA`; el registro decrementa una vez en el flanco positivo que lleva a `ESPERA_RESTART`. |
| `decrement_stock_B` | `ENTREGA` | El producto almacenado en `selected_product_reg` es B. | Mealy | Registro `inventory_B_reg`. | Un único pulso durante el ciclo de `ENTREGA`; el registro decrementa una vez en el flanco positivo que lleva a `ESPERA_RESTART`. |
| `decrement_stock_C` | `ENTREGA` | El producto almacenado en `selected_product_reg` es C. | Mealy | Registro `inventory_C_reg`. | Un único pulso durante el ciclo de `ENTREGA`; el registro decrementa una vez en el flanco positivo que lleva a `ESPERA_RESTART`. |
| `delivery_led_A` | `ENTREGA` | El producto almacenado en `selected_product_reg` es A. | Mealy | LED de entrega del producto A. | La duración visible debe definirse independientemente del decremento. Un ciclo de reloj de 27 MHz equivale aproximadamente a 37 ns y no sería perceptible visualmente. |
| `delivery_led_B` | `ENTREGA` | El producto almacenado en `selected_product_reg` es B. | Mealy | LED de entrega del producto B. | La duración visible debe definirse independientemente del decremento. Un ciclo de reloj de 27 MHz equivale aproximadamente a 37 ns y no sería perceptible visualmente. |
| `delivery_led_C` | `ENTREGA` | El producto almacenado en `selected_product_reg` es C. | Mealy | LED de entrega del producto C. | La duración visible debe definirse independientemente del decremento. Un ciclo de reloj de 27 MHz equivale aproximadamente a 37 ns y no sería perceptible visualmente. |
| `refund_indicator` | `DEVOLUCION` | Ninguna condición de terminación definida. La ruta puede corresponder a producto agotado; el destino por pago insuficiente está pendiente. | Moore | Indicador/LED de devolución. No especifica un mecanismo físico de devolución. | Activa mientras la FSM permanezca en `DEVOLUCION`; no se asigna un número de ciclos ni un temporizador. |
| `clear_transaction` | `ESPERA_RESTART` | `restart_event=1`, aceptado para iniciar otra transacción. No debe limpiar inventarios. | Mealy | Registros temporales de solicitud, crédito, precio, vuelto y demás datos de transacción que se acuerden. | En el flanco positivo que acepta `RESTART` y lleva a `REPOSO`. El alcance exacto de los registros que se limpian requiere definición de la ruta de datos. |
| `reset_inventory` (control global de S1) | S1, desde cualquier estado | S1 activo; no es una acción de `RESTART`. | No aplica: reset global, no salida Moore/Mealy de la FSM. | `inventory_A_reg`, `inventory_B_reg` e `inventory_C_reg`; cada registro se restablece a tres unidades. | Momento y polaridad dependen de si el reset se implementa síncrono o asíncrono; deben definirse antes de conectar módulos. En cualquier caso, `RESTART` no activa este control. |

## Secuencia síncrona obligatoria para el cálculo

| Fase | Estado antes del flanco | Salidas activas | Acción en el flanco |
|---|---|---|---|
| **E0: cargar operandos** | `CARGA_Y_REVISION` | `load_price=1`, `load_credit=1`, `calculate_balance=0` | Se registran precio y crédito. Si el producto está disponible, la FSM avanza a `LANZAR_CALCULO`; si está agotado, pasa a `DEVOLUCION` sin decrementar inventario. |
| **E1: lanzar resta** | `LANZAR_CALCULO` | `calculate_balance=1` durante un único ciclo | El restador muestrea `calculate=1`, registra magnitud y signo y activa `result_valid`; la FSM avanza a `CALCULO_SALDO` y todavía no consume el nuevo resultado en este mismo flanco. |
| **E2: consumir resultado** | `CALCULO_SALDO` | `calculate_balance=0`; `load_change=1` solo si `result_valid=1` y `negative=0` | La FSM consume `result_valid`. Si `negative=0`, `magnitude` se registra como vuelto y la FSM avanza a `ENTREGA`. Si `negative=1`, no carga vuelto, no entrega y no decrementa inventario; el destino permanece pendiente. Si `result_valid=0`, permanece en `CALCULO_SALDO` sin volver a lanzar la resta. |

## Distinción entre indicación y actualización de inventario

En `ENTREGA`, exactamente una de las señales `decrement_stock_A/B/C` produce la actualización del inventario una sola vez: es un pulso asociado al producto capturado, aceptado por el registro en el flanco de salida a `ESPERA_RESTART`. Las señales `delivery_led_A/B/C` son indicaciones distintas y su duración visible necesita una definición independiente. Si se activaran solo durante el ciclo de `ENTREGA`, permanecerían encendidas aproximadamente 37 ns con un reloj de 27 MHz, insuficiente para ser perceptibles visualmente. No se debe prolongar el decremento para extender la indicación del LED.

`RESTART`, aceptado en `ESPERA_RESTART`, puede activar `clear_transaction` para comenzar otra compra, pero conserva los tres inventarios. S1 es independiente: debe restaurar los inventarios A, B y C a tres unidades y reiniciar el control según la estrategia de reset que se acuerde.

## Señales y asignaciones pendientes

- **Monedas:** el enunciado describe `IN_COINS` como cantidad de monedas de ₡100, pero los escenarios mencionan también ₡50 y ₡25. La captura y carga del crédito dependen de aclarar su codificación.
- **Pago insuficiente:** no se define si `negative=1` inicia una devolución automáticamente o si depende de otra interacción. No se crea una entrada `CANCEL`, ni se asigna una señal de control de devolución de dinero.
- **Devolución y agotamiento:** el enunciado pide indicar la devolución cuando el producto está agotado, pero no especifica duración, condición de terminación ni temporizador. La duración de `refund_indicator` y la salida de `DEVOLUCION` permanecen pendientes.
- **Temporizadores de 2 segundos:** no se atribuyen a los LEDs de entrega, a `DEVOLUCION` ni a otro estado hasta que se aclare qué acciones deben temporizarse; el enunciado no establece expresamente que los LEDs deban mantenerse activos durante 2 segundos.
- **Display:** se conserva la contradicción entre mostrar el vuelto y la instrucción «No conecte este bloque». No se añade aquí una salida de despliegue ni se conecta el bloque.
- **Reset S1:** está establecido que restaura inventarios, pero quedan por definir la polaridad, sincronía y adaptación de reset para los módulos reutilizables.
- **`clear_transaction`:** se propone asociarlo a la aceptación de `RESTART`; su alcance preciso y la limpieza necesaria al cerrar una devolución no se fijan sin conocer la secuencia de cierre.

La tabla no asigna salidas nuevas a `RETORNO_REPOSO`: la condición para entrar y salir de esa ruta depende de aclarar la terminación de la devolución. Tampoco asigna controles de transacción a `REPOSO` ni a `ESPERA_RESTART` mientras no haya un evento válido. Todas estas salidas deben revisarse junto con la FSM y la ruta de datos antes de derivar ecuaciones o implementar el diseño.

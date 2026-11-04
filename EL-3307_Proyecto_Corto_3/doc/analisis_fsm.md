# Análisis preliminar de la FSM principal

## Alcance y fuentes

Este documento plantea estados candidatos para iniciar el diseño de la unidad de control de la máquina expendedora. Es una propuesta para revisión del grupo y del profesor; no fija todavía una máquina definitiva, sus ecuaciones ni su implementación.

Se consideran como fuentes el enunciado oficial del Proyecto Corto 3 y los documentos [`arquitectura_general.md`](./arquitectura_general.md), [`diseno_subsistemas.md`](./diseno_subsistemas.md) y [`diagrama_bloques.md`](./diagrama_bloques.md). Como marco teórico se utiliza Harris y Harris, *Digital Design and Computer Architecture, ARM Edition*, en particular las secciones sobre máquinas de estados finitos y su descripción en HDL (secciones 3.4 y 4.6). La separación conceptual es la siguiente: la FSM decide la secuencia y emite señales de control; la ruta de datos realiza las operaciones aritméticas y actualiza sus registros.

En adelante:

- **Requisito oficial** identifica un comportamiento expresado en el enunciado.
- **Propuesta del grupo** identifica un candidato que debe revisarse antes de fijar la tabla final.
- Los nombres de señales y estados son descriptivos; no son nombres prescritos por el enunciado.

## Requisitos oficiales relevantes

- La FSM principal debe usar codificación **One-Hot**. El diseño final deberá presentar diagrama de estados, tabla de transición y ecuaciones de siguiente estado y de salida.
- La FSM controla una ruta de datos separada. Las operaciones aritméticas y las actualizaciones de registros no deben ejecutarse dentro de la FSM.
- La máquina tiene productos A, B y C, con precios ₡150, ₡275 y ₡400 y tres unidades iniciales de inventario por producto.
- Una entrega debe indicarse mediante el LED del producto correspondiente y reducir su inventario. El inventario debe indicar agotamiento mediante un LED particular.
- Si se selecciona un producto agotado, el enunciado requiere devolver todas las monedas y regresar al reposo.
- Si el crédito alcanza o supera el precio, se entrega el producto y se determina el vuelto.
- Después de la entrega se requiere presionar `RESTART` para iniciar de nuevo, sin borrar el inventario.
- S1 es el reset global; el enunciado especifica que restaura los registros de inventario.
- La condición de crédito suficiente se obtiene a partir del signo de una resta, no mediante un operador de comparación.
- El sistema debe usar un solo reloj de 27 MHz; las bases de tiempo y temporizadores de 2 s se generan mediante habilitaciones derivadas de ese reloj.

## Estados candidatos

Los siguientes nombres y la separación de acciones en varios estados son **propuestas del grupo**, no una secuencia impuesta literalmente por el enunciado. Separar carga, cálculo y consumo de resultados registrados facilita respetar la separación entre control y ruta de datos.

| Estado candidato | Función y acciones posibles |
|---|---|
| `REPOSO` | Esperar una solicitud nueva. No modificar inventarios. La señal de `RESTART` debe dejar el sistema listo para aceptar otra transacción, pero no restablece el inventario. |
| `CAPTURA_SOLICITUD` | Aceptar la selección de producto y el valor/cantidad de monedas cuando se detecte una solicitud válida mediante `START`; conservar la solicitud en registros de entrada. La codificación y el instante de captura de `IN_COINS` están pendientes. |
| `CARGA_Y_REVISION` | Registrar el precio del producto seleccionado y el crédito capturado, con `calculate=0`, y consultar su disponibilidad. Al final de este estado, los operandos ya deben estar registrados y estables. |
| `LANZAR_CALCULO` | Estado propuesto de un ciclo que activa `calculate_balance` una sola vez. Sus operandos proceden de los registros de precio y crédito cargados en el estado anterior. |
| `CALCULO_SALDO` | Esperar y consumir `result_valid` del restador. Cuando vale 1, usar `negative` para decidir el siguiente estado; si el crédito es suficiente, capturar `magnitude` como vuelto en ese flanco. |
| `DECISION_SALDO` | Estado candidato reservado exclusivamente para la alternativa A, que registra primero la decisión. No forma parte del flujo preferido con `LANZAR_CALCULO`. |
| `ENTREGA` | Activar la indicación de entrega del producto elegido y emitir un único pulso de decremento para ese producto. Este estado puede ser breve; su duración y señalización final deben verificarse. |
| `ESPERA_RESTART` | Mantener el sistema al final de una compra y esperar `RESTART`, que inicia otra transacción sin alterar inventarios. |
| `DEVOLUCION` | Activar la indicación de devolución y disponer la devolución del monto correspondiente según la política aprobada. Puede usarse para producto agotado y, si así se acuerda, para pago insuficiente. No presupone un mecanismo físico de devolución. |
| `RETORNO_REPOSO` | Cerrar una ruta de rechazo/devolución y volver a `REPOSO` cuando se cumpla la condición de finalización aprobada. Podría fusionarse con `DEVOLUCION` si la señalización no requiere permanencia. |

La propuesta incluye diez estados: los nueve candidatos originales más `LANZAR_CALCULO`. `DECISION_SALDO` se conserva únicamente para documentar la alternativa A y no se conecta al flujo preferido de la alternativa B.

### Codificación

**Requisito oficial:** implementar la FSM principal con codificación One-Hot. En la propuesta, cada estado candidato tendría su propio bit de estado y el estado de reset sería `REPOSO`. La codificación concreta, el ancho de estado y la tabla definitiva se decidirán en una fase posterior. Aquí no se derivan ecuaciones ni se escribe código.

## Transiciones candidatas

| Estado actual | Evento o condición de transición | Estado siguiente candidato | Observación |
|---|---|---|---|
| `REPOSO` | Solicitud válida confirmada por `START` | `CAPTURA_SOLICITUD` | Requiere entrada sincronizada y pulsador acondicionado. El significado exacto de una solicitud válida depende del formato de los DIP. |
| `CAPTURA_SOLICITUD` | Producto e importe capturados | `CARGA_Y_REVISION` | Propuesta: asegurar que la solicitud quedó registrada antes de usarla en la ruta de datos. |
| `CARGA_Y_REVISION` | Producto disponible | `LANZAR_CALCULO` | En este ciclo se registran precio y crédito con `calculate=0`. La selección y el crédito ya fueron capturados; no se usan directamente los DIP vivos. |
| `CARGA_Y_REVISION` | Producto agotado (`selected_empty`) | `DEVOLUCION` | **Requisito oficial:** indicar devolución de todas las monedas y regresar al reposo. El criterio temporal para terminar la indicación requiere aclaración. |
| `LANZAR_CALCULO` | Estado de lanzamiento de un ciclo | `CALCULO_SALDO` | Durante este único ciclo, `calculate_balance=1`; en el flanco de salida el restador registra el resultado y activa `result_valid`. |
| `CALCULO_SALDO` | `result_valid=1` y `negative=0` | `ENTREGA` | Alternativa B preferida: en el flanco que consume el resultado, cargar `magnitude` en el registro de vuelto y registrar la transición. |
| `CALCULO_SALDO` | `result_valid=1` y `negative=1` | `DEVOLUCION` o estado pendiente | Alternativa B preferida; la política de pago insuficiente sigue pendiente. No se agrega una entrada `CANCEL`. |
| `CALCULO_SALDO` | `result_valid=0` | `CALCULO_SALDO` | Esperar el resultado sin volver a activar `calculate_balance`; `magnitude` y `negative` retenidos no autorizan una decisión nueva. |
| `DECISION_SALDO` | Decisión suficiente previamente registrada | `ENTREGA` | Solo aplica a la alternativa A; no se conecta al flujo preferido. |
| `DECISION_SALDO` | Decisión insuficiente previamente registrada | `DEVOLUCION` o estado pendiente | Solo aplica a la alternativa A; la ruta concreta sigue pendiente de aclaración. |
| `ENTREGA` | Acción de entrega y pulso único de decremento completados | `ESPERA_RESTART` | La acción de decremento ocurre una sola vez durante el ciclo de `ENTREGA`; no se mantiene activa durante una espera. |
| `ESPERA_RESTART` | Evento válido de `RESTART` | `REPOSO` | **Requisito oficial:** reiniciar la transacción sin restablecer inventarios. |
| `DEVOLUCION` | Devolución/indicación terminada según política acordada | `RETORNO_REPOSO` | No se define duración ni condición de terminación en el enunciado. No se presupone que `RESTART` o una cancelación sean necesarios en esta ruta. |
| `RETORNO_REPOSO` | Cierre de la ruta de devolución | `REPOSO` | Debe acordarse si es un estado separado o si `DEVOLUCION` vuelve directamente a reposo. |
| Cualquier estado | Reset global S1 activo | `REPOSO` | **Requisito oficial:** reset global, incluidas las existencias restauradas a tres. La prioridad/reset eléctrico y su sincronía deben fijarse en el diseño. |

La tabla no determina qué hacer con solicitudes durante una compra, señales simultáneas, entradas inválidas ni pulsos de botones mantenidos. Esas reglas deben añadirse antes de congelar la FSM.

## Señales entre la FSM y la ruta de datos

### Señales de control emitidas por la FSM

Son nombres candidatos del grupo para expresar las operaciones que el enunciado asigna a la ruta de datos:

| Señal candidata | Operación controlada |
|---|---|
| `capture_request` o `load_product` | Capturar producto seleccionado para la transacción |
| `load_price` | Cargar en el registro de precio el valor del producto seleccionado |
| `load_credit` | Cargar el importe ingresado en el registro de crédito |
| `add_credit` | Acumular crédito, solo si el protocolo de entrada finalmente requiere acumulación |
| `calculate_balance` | Conectada a la entrada `calculate` del restador; solicita una sola resta como pulso de un ciclo durante `LANZAR_CALCULO`, después de cargar y estabilizar precio y crédito |
| `load_change` | En `CALCULO_SALDO`, guardar `magnitude` como vuelto únicamente en el flanco en que `result_valid=1` y `negative=0` |
| `decrement_stock_A/B/C` | Disminuir una unidad del producto efectivamente entregado; generar una sola acción por transacción de entrega |
| `load_refund` o `refund_active` | Señalizar la ruta de devolución; el valor/registro utilizado depende de la política aclarada |
| `clear_transaction` | Limpiar registros temporales al comenzar o cerrar una transacción, sin borrar inventarios |

Las señales de control deben causar acciones síncronas de la ruta de datos y no realizar las operaciones en la lógica de la FSM. `calculate_balance` es un pulso único en `LANZAR_CALCULO`; `load_change` se condiciona a `result_valid` en `CALCULO_SALDO`. El decremento debe ocurrir una vez durante el ciclo de `ENTREGA`, aun si posteriormente se decide mantener activa la indicación del LED.

### Señales de condición recibidas por la FSM

| Señal candidata | Uso en decisiones de la FSM |
|---|---|
| `request_valid` / evento de `START` | Indicar que producto e importe fueron capturados como solicitud |
| `selected_product` | Identificar cuál precio, inventario y LED corresponden a la solicitud |
| `selected_available` / `selected_empty` | Elegir entre cálculo de saldo o rechazo por agotamiento |
| `result_valid` | Indicar que el resultado del restador está disponible para esta operación |
| `negative` | Con `result_valid=1`, identificar el signo según la orientación crédito menos precio |
| `magnitude` | Con `result_valid=1`, interpretar faltante o vuelto según el signo |
| `timer_done` | Condición de expiración para un temporizador que se defina; uso aún pendiente |
| `restart_event` | Solicitud de reinicio de transacción al terminar la compra |

La FSM debe ignorar el signo y la magnitud mientras `result_valid` no indique un resultado nuevo válido. En el módulo reutilizado, `magnitude` y `negative` son salidas registradas: conservan su último valor después de que `result_valid` vuelva a cero, pero ese valor retenido no es un resultado nuevo ni una señal de validez permanente.

### Temporización de `calculate` y `result_valid`

En el flujo preferido se incorpora el estado de un ciclo `LANZAR_CALCULO` para separar la carga de operandos del lanzamiento del restador. El módulo `subtractor.sv` del Proyecto Corto 2 muestrea `calculate` en el flanco positivo. Si lo muestrea alto, registra `magnitude` y `negative` y activa `result_valid`. Si `calculate` está bajo en el siguiente flanco, `result_valid` vuelve a cero, mientras que `magnitude` y `negative` conservan sus valores registrados anteriores.

La secuencia propuesta es:

| Flanco | Estado justo antes del flanco | Operandos antes del flanco | Señales de carga antes del flanco | `calculate` | Actualización del restador y FSM |
|---|---|---|---|---:|---|
| E0 | `CARGA_Y_REVISION` | La selección y el importe ya fueron capturados; `price_reg` y `credit_reg` aún pueden contener datos anteriores | `load_price=1`, `load_credit=1` | 0 | En E0 se registran precio y crédito. Si el producto está disponible, la FSM cambia a `LANZAR_CALCULO`; si está agotado, pasa a `DEVOLUCION`. No se calcula en E0. |
| E1 | `LANZAR_CALCULO` | `price_reg` y `credit_reg` contienen los valores nuevos desde E0 y están estables antes del flanco | Ninguna carga de operandos | 1, durante este único ciclo | El restador acepta la solicitud y registra `magnitude`, `negative` y `result_valid=1`. La FSM cambia a `CALCULO_SALDO`; en E1 aún muestrea el valor previo de `result_valid`, así que no decide ahí. |
| Entre E1 y E2 | `CALCULO_SALDO` | Precio y crédito se mantienen estables; las salidas registradas contienen el resultado nuevo | `load_change=0` hasta validar el resultado | 0 | `result_valid` está alto durante este ciclo; magnitud y signo son válidos para la operación solicitada. |
| E2 | `CALCULO_SALDO` | Los operandos siguen estables; `magnitude` y `negative` son el resultado registrado | Si `result_valid=1` y `negative=0`, `load_change=1`; en otro caso `load_change=0` | 0 | La FSM consume `result_valid` y registra su transición. Con `negative=0`, registra `magnitude` como vuelto y pasa a `ENTREGA`. Con `negative=1`, pasa a la ruta provisional de pago insuficiente sin entregar ni decrementar inventario. Después de E2 el restador baja `result_valid`, conservando magnitud/signo. |

Así, los operandos nuevos se registran en E0, antes de que `calculate` sea muestreado alto en E1. El `result_valid` que activa el restador después de E1 se consume en E2; no se pierde por el cambio de estado ni se interpreta el valor anterior en E1.

#### Alternativa A: registrar primero la decisión

Como alternativa, en E2 la FSM podría capturar una bandera de decisión mientras `result_valid=1`, pasar a `DECISION_SALDO` y usar esa bandera en el ciclo siguiente para decidir entre entrega y la ruta pendiente de pago insuficiente. La magnitud del vuelto también tendría que capturarse en E2 o registrarse desde la ruta de datos en ese flanco. Esta alternativa necesita almacenamiento de decisión adicional. `DECISION_SALDO` se conserva en la lista únicamente para describir esta opción y no forma parte del flujo preferido.

#### Propuesta provisional: alternativa B

Se prefiere provisionalmente la alternativa B: `CALCULO_SALDO` usa `result_valid` y `negative` en E2 para registrar directamente la transición, y en el caso suficiente carga `magnitude` en `change_reg` en ese mismo flanco. Esta opción evita la bandera de decisión auxiliar. La FSM no debe intentar consumir el resultado en E1: en ese flanco todavía observa el `result_valid` anterior. El grupo debe confirmar que las señales de carga de la ruta de datos están habilitadas por las condiciones válidas del E2.

## Tratamiento funcional de los escenarios

### Inventario agotado

La FSM consulta `selected_empty` antes de calcular o entregar. Si el producto elegido está agotado, no debe emitir una orden de decremento ni una señal de entrega para ese producto. El enunciado exige indicar devolución de todas las monedas y regresar a reposo; la duración del LED y el modo de finalizar esa ruta no están especificados.

### Pago suficiente

Solo durante el ciclo en que `result_valid=1` la FSM puede interpretar el signo de la resta. En la alternativa B preferida, si `negative=0`, la FSM registra directamente la transición a `ENTREGA` y carga `magnitude` como vuelto en el flanco de consumo. El crédito exacto produce vuelto cero. El decremento del inventario se ejecuta una sola vez durante el ciclo posterior de `ENTREGA`. El uso del display queda sujeto a la instrucción contradictoria del enunciado («No conecte este bloque»).

### Pago insuficiente

El enunciado de la ruta aritmética indica devolver las monedas si hay faltante, pero el escenario de verificación describe pago insuficiente y luego cancelación. **No se define aquí una entrada `CANCEL` ni se decide si la devolución es automática o depende de otra acción.** En el flujo preferido, el destino desde `CALCULO_SALDO` cuando `result_valid=1` y `negative=1` queda pendiente de aclaración. `DECISION_SALDO` solo corresponde a la alternativa A. La ruta no debe avanzar a `ENTREGA` ni decrementar inventario.

### `RESTART` y reset global S1

- **`RESTART`:** al terminar la entrega, vuelve a iniciar el sistema para otra transacción y no altera los inventarios.
- **S1:** es el reset global. Lleva la FSM al estado inicial y restaura cada inventario a tres unidades, según el enunciado. La polaridad activa, sincronía y adaptación a los resets de los módulos reutilizables deben verificarse; no se asume aquí una conexión eléctrica concreta.

### Prevención de decrementos repetidos

La selección de producto debe ser la capturada en la solicitud aceptada y mantenerse estable durante la revisión, el cálculo y la entrega; la FSM no debe volver a leer el DIP vivo para decidir qué precio usar ni qué inventario modificar. El crédito también debe provenir del valor capturado antes de activar `calculate_balance`.

La orden de decremento debe generarse una sola vez por entrega confirmada. Como propuesta, mantener `ENTREGA` como un ciclo de acción único: la señal de decremento del producto seleccionado se activa solo durante ese ciclo y la transición siguiente es a `ESPERA_RESTART`. Si la señal del LED debe permanecer activa durante más tiempo, su mantenimiento debe separarse de la habilitación de decremento; no se debe usar un nivel prolongado para restar inventario en varios flancos. El punto de confirmación de entrega debe decidirse al especificar la ruta de datos.

`RESTART` solo debe limpiar/reiniciar los registros temporales de la transacción y devolver el control a `REPOSO`; no debe activar los registros de inventario. S1, en cambio, es el reset global y debe inicializar cada inventario en tres unidades, además del estado de control. La polaridad y la adaptación de reset continúan pendientes.

## Aclaraciones requeridas antes de fijar transiciones

1. **Representación de monedas:** `IN_COINS` se describe como cantidad de monedas de ₡100, mientras que los casos de prueba usan también ₡50 y ₡25. Deben confirmarse codificación, ancho y unidad; hasta entonces no se pueden fijar completamente captura, carga ni escenarios aritméticos.
2. **Pago insuficiente/cancelación:** debe aclararse cómo se inicia la devolución, qué evento la termina y si existe alguna señal adicional. No se incorpora una entrada `CANCEL` sin definición oficial.
3. **Producto agotado:** confirmar cuánto tiempo se activa el LED de devolución y cuál es la condición para volver al reposo.
4. **Temporizadores de 2 s:** el enunciado pide temporizadores, pero no define qué estados o acciones temporizan, cuántos hay ni las condiciones de inicio, parada y expiración.
5. **Señalización de entrega y devolución:** aclarar si los LEDs se activan como pulso, por un intervalo temporizado o hasta una interacción del usuario.
6. **Prioridad y uso de `RESTART`:** el enunciado lo requiere tras una entrega; debe aclararse su comportamiento en rechazo/devolución y ante pulsaciones fuera del estado de espera.
7. **Reset S1:** confirmar polaridad eléctrica y estrategia de sincronía/adaptación para compatibilizar el reset global con los bloques reutilizables, sin perder el requisito de reinicializar inventarios.
8. **Despliegue:** el enunciado solicita mostrar el vuelto, pero también dice «No conecte este bloque». Mantener fuera las transiciones y salidas que dependan de conectar el display hasta obtener respuesta.
9. **Solicitud inválida o simultánea:** especificar respuesta a códigos DIP no asignados, cambios de DIP durante una transacción y pulsaciones múltiples o mantenidas.

## Próximo paso de diseño

Con las aclaraciones anteriores, se podrá consolidar la lista de estados, definir condiciones mutuamente excluyentes y prioridades, construir el diagrama y la tabla finales, y luego derivar ecuaciones de siguiente estado y de salida conforme al formato requerido. Este análisis no sustituye esos artefactos y no declara validada la integración.

# Tabla preliminar de transiciones de la FSM

## Alcance y convenciones

Esta tabla es una propuesta para revisión, basada en el [enunciado oficial del Proyecto Corto 3](./Proyectos_Proyecto-Corto-3-II-Semestre-2026.pdf) y en el análisis FSM y diagrama de estados preliminares. Se utiliza el enfoque de Harris y Harris, *Digital Design and Computer Architecture, ARM Edition*: la FSM controla la secuencia y la ruta de datos realiza y registra las operaciones síncronas. La tabla no deriva ecuaciones ni especifica SystemVerilog.

La codificación requerida por el enunciado es **One-Hot**. El flujo activo aquí propuesto tiene nueve estados:

1. `REPOSO`
2. `CAPTURA_SOLICITUD`
3. `CARGA_Y_REVISION`
4. `LANZAR_CALCULO`
5. `CALCULO_SALDO`
6. `ENTREGA`
7. `ESPERA_RESTART`
8. `DEVOLUCION`
9. `RETORNO_REPOSO`

`DECISION_SALDO` queda documentado al final como estado reservado para la alternativa A; no pertenece a los nueve estados activos ni al flujo preferido.

Los nombres de señales entre paréntesis son propuestas descriptivas del grupo, no nombres exigidos por el enunciado. Se supone un solo reloj de 27 MHz. E0, E1 y E2 identifican flancos consecutivos de la secuencia de cálculo.

## Tabla de transiciones

| Estado actual | Condición o evento | Estado siguiente | Señales de control activas | Permanencia y observaciones síncronas |
|---|---|---|---|---|
| `REPOSO` | Solicitud válida mediante `START` (`request_valid`) | `CAPTURA_SOLICITUD` | Ninguna operación aritmética. | Si no hay solicitud válida, permanece en `REPOSO`. `RESTART` no restablece inventario. S1 tiene prioridad global: lleva a `REPOSO` y reinicia inventarios a tres. |
| `CAPTURA_SOLICITUD` | Producto e importe capturados desde las entradas acondicionadas | `CARGA_Y_REVISION` | Capturar/retener `selected_product` y el importe (`capture_request`, nombre propuesto). | La selección e importe quedan registrados antes de cargar precio o lanzar la resta. Cambios posteriores de los DIP no deben cambiar los operandos de la transacción en curso. El ancho y codificación de `IN_COINS` siguen pendientes. |
| `CARGA_Y_REVISION` | Producto seleccionado disponible | `LANZAR_CALCULO` | En **E0**: `load_price=1`, `load_credit=1`, `calculate=0`. | Los valores fuente son la selección y el crédito capturados previamente, no los pines DIP. En el flanco E0 se registran `price_reg` y `credit_reg`; al mismo tiempo la FSM cambia a `LANZAR_CALCULO`. Así los operandos nuevos quedan estables antes del flanco que muestrea `calculate=1`. |
| `CARGA_Y_REVISION` | Producto seleccionado agotado (`selected_empty`) | `DEVOLUCION` | En **E0**: `load_price=1`, `load_credit=1`, `calculate=0`; activar la ruta/indicación de devolución según la interfaz aprobada; no activar `decrement_stock`. | Las cargas E0 toman los datos capturados, pero no se solicita la resta si el producto está agotado. El enunciado exige devolver todas las monedas y regresar al estado inicial. Duración de la indicación y condición de cierre no especificadas. No se disminuye inventario. |
| `LANZAR_CALCULO` | Estado de lanzamiento de un ciclo | `CALCULO_SALDO` | En **E1**: `calculate_balance=1` durante un único ciclo; equivale a activar la entrada `calculate` del restador. | `price_reg` y `credit_reg` ya estaban registrados desde E0. En E1 el restador registra `magnitude`, `negative` y activa `result_valid`. La FSM cambia a `CALCULO_SALDO`, pero en ese mismo flanco aún observa el `result_valid` anterior; no debe decidir todavía. |
| `CALCULO_SALDO` | `result_valid=1` y `negative=0` | `ENTREGA` | En **E2**: `load_change=1` para registrar `magnitude` como vuelto; `calculate_balance=0`. | La FSM consume la validez en E2, registra la transición y captura el vuelto en el mismo flanco. El restador baja `result_valid` después de E2 y retiene signo/magnitud; esos valores retenidos no autorizan decisiones posteriores sin nueva validez. No se usa un comparador de magnitud. |
| `CALCULO_SALDO` | `result_valid=1` y `negative=1` | **Pendiente de aclaración**; `DEVOLUCION` es destino candidato | `calculate_balance=0`; no activar `load_change` ni `decrement_stock`. | Significa que la resta crédito-precio es negativa. El enunciado aritmético indica devolver el pago insuficiente, pero el escenario de verificación menciona cancelar después del pago. No se inventa una entrada `CANCEL` ni se fija una transición hasta aclarar esa contradicción. |
| `CALCULO_SALDO` | `result_valid=0` | `CALCULO_SALDO` | `calculate_balance=0`; no cargar vuelto ni emitir decremento. | Permanece esperando validez. No vuelve a lanzar el cálculo; magnitud y signo retenidos no se consideran resultado nuevo. En la secuencia prevista, `result_valid` se activa después de E1 y se consume en E2. |
| `ENTREGA` | Ciclo único de acción de entrega | `ESPERA_RESTART` | Activar el LED de entrega correspondiente y un único pulso `decrement_stock_<producto>`. | La ruta de datos acepta el decremento una sola vez en el flanco de salida de este ciclo. Si el LED debe permanecer encendido más tiempo, su señalización debe separarse del pulso de decremento para no reducir el inventario varias veces. |
| `ESPERA_RESTART` | Evento acondicionado de `RESTART` (`restart_event`) | `REPOSO` | Limpiar registros temporales de transacción si se define `clear_transaction`; no activar reset de inventario. | Sin `RESTART`, permanece esperando. **Requisito oficial:** iniciar otra transacción sin alterar el inventario. S1, si se activa, sigue siendo el reset global y no equivale a `RESTART`. |
| `DEVOLUCION` | Condición de fin de devolución/indicación | `RETORNO_REPOSO` (candidata; condición pendiente) | Mantener la indicación de devolución mientras la política acordada lo requiera; no decrementar inventario. | El enunciado no especifica duración, señal de confirmación ni evento de terminación. No se supone `RESTART`, `CANCEL` ni expiración de temporizador sin aclaración. Si no se conoce la condición de fin, la permanencia debe quedar sin fijar. |
| `RETORNO_REPOSO` | Cierre de la ruta de devolución, una vez acordado | `REPOSO` | Desactivar las señales temporales de devolución y limpiar datos temporales solo según protocolo definido. | Estado candidato para separar el fin de devolución del reposo. Puede requerir un ciclo o fusionarse con `DEVOLUCION`; no se fija esa decisión sin conocer duración y temporización. |
| Cualquier estado | Reset global S1 activo | `REPOSO` | Reset de la FSM y de los registros globales; inicializar `inventory_A`, `inventory_B` e `inventory_C` a tres unidades. | **Requisito oficial:** S1 restaura el inventario. La polaridad y adaptación/sincronía del reset deben revisarse para los módulos que se reutilicen. Esta fila tiene prioridad sobre las transiciones ordinarias. |

## Secuencia de operandos y restador: E0, E1 y E2

La captura de solicitud y la carga de operandos son acciones distintas:

| Momento | Estado antes del flanco | Datos disponibles antes del flanco | Controles | Efecto del flanco |
|---|---|---|---|---|
| Antes de E0 | `CARGA_Y_REVISION` | Producto e importe ya están capturados en registros de solicitud. Los registros de operandos del restador aún pueden contener datos anteriores. | `load_price=1`, `load_credit=1`, `calculate=0` | En E0 se registran precio y crédito. Si el producto está disponible, la FSM entra en `LANZAR_CALCULO`; si está agotado, va a `DEVOLUCION` sin decremento. |
| Antes de E1 | `LANZAR_CALCULO` | `price_reg` y `credit_reg` tienen los valores cargados en E0 y están estables. | `calculate_balance=1` solo durante este ciclo. | En E1 el restador muestrea `calculate=1`, actualiza `magnitude` y `negative`, pone `result_valid=1`; la FSM entra en `CALCULO_SALDO` sin usar en E1 el valor nuevo de validación. |
| Antes de E2 | `CALCULO_SALDO` | `result_valid=1`; magnitud y signo son el resultado registrado en E1. | Si `negative=0`, activar `load_change`; en ambos casos `calculate_balance=0`. | En E2 la FSM consume `result_valid`. Si `negative=0`, registra `magnitude` como vuelto y transita a `ENTREGA`. Si `negative=1`, no carga vuelto como cambio ni entrega; el destino de pago insuficiente sigue pendiente. Después de E2 `result_valid` baja, y la FSM no debe reutilizarlo como válido. |

Esta secuencia requiere que el precio y el crédito fuente estén capturados antes de E0, que sus registros de operandos se carguen en E0, y que `calculate` se active únicamente en E1. Así el restador no consume valores viejos por una carga y cálculo simultáneos.

## Estado reservado: `DECISION_SALDO`

`DECISION_SALDO` se conserva únicamente para documentar la alternativa A: capturar una bandera de decisión mientras `result_valid=1` y usarla después. No forma parte de los nueve estados activos de esta tabla y no debe intercalarse en el flujo preferido de alternativa B, que decide directamente desde `CALCULO_SALDO` en E2.

## Requisitos y pendientes de aclaración

- **Requisito oficial:** FSM One-Hot; control separado de la ruta de datos; productos con precios ₡150/₡275/₡400; inventario inicial de tres unidades; decremento por entrega; LEDs de entrega y agotado; devolución para producto agotado; `RESTART` sin borrar inventario; S1 como reset global; suficiencia obtenida desde el signo de la resta; un reloj de 27 MHz y bases de tiempo mediante pulsos de habilitación.
- **Monedas:** el enunciado describe `IN_COINS` como cantidad de monedas de ₡100, mientras que los escenarios incluyen denominaciones de ₡50 y ₡25. No se define aquí la codificación ni se ajustan transiciones numéricas por suposición.
- **Pago insuficiente/devolución:** la instrucción de devolver si el pago es insuficiente no queda alineada con el escenario que menciona cancelar. El destino y la terminación de esa ruta permanecen pendientes; no se añade una entrada `CANCEL`.
- **Temporizadores de 2 segundos:** el enunciado solicita temporizadores, pero no identifica qué estados o acciones deben durar ese intervalo ni cuántos temporizadores hacen falta. Las transiciones de cierre de `DEVOLUCION` y `RETORNO_REPOSO` no pueden depender de una condición temporal todavía no definida.
- **Display:** se requiere mostrar vuelto, pero también aparece la instrucción «No conecte este bloque». Esta tabla no supone una conexión del despliegue.
- **Reset:** distinguir S1 de `RESTART` está definido funcionalmente, pero la polaridad y la estrategia de adaptación a los resets de módulos reutilizables deben confirmarse.

Esta tabla no es la especificación final. Antes de fijar la secuencia completa se deben resolver las ambigüedades con el profesor y definir prioridades, eventos de cierre y temporización. No se derivan ecuaciones de estado ni ecuaciones de salida.

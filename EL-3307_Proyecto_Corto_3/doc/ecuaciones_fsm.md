# Derivación preliminar de ecuaciones One-Hot de la FSM

## Alcance y fuentes

Este documento inicia la derivación de ecuaciones para la propuesta FSM del Proyecto Corto 3. Se apoya en el [enunciado oficial](./Proyectos_Proyecto-Corto-3-II-Semestre-2026.pdf), el [análisis FSM](./analisis_fsm.md), el [diagrama de estados](./diagrama_estados_fsm.md), la [tabla de transiciones](./tabla_transiciones_fsm.md), la [tabla de salidas de control](./tabla_salidas_control_fsm.md) y el enfoque de máquinas de estados y lógica secuencial de Harris y Harris, *Digital Design and Computer Architecture, ARM Edition*.

Las expresiones son preliminares y no constituyen una especificación definitiva. Se derivan únicamente términos respaldados por la tabla; los términos que dependen de decisiones o condiciones aún no definidas se identifican como pendientes. No se derivan ecuaciones de temporizadores, no se añade una entrada `CANCEL` y no se escribe SystemVerilog.

## Asignación One-Hot propuesta

Se adopta provisionalmente la asignación indicada:

| Bit | Estado |
|---|---|
| \(Q_0\) | `REPOSO` |
| \(Q_1\) | `CAPTURA_SOLICITUD` |
| \(Q_2\) | `CARGA_Y_REVISION` |
| \(Q_3\) | `LANZAR_CALCULO` |
| \(Q_4\) | `CALCULO_SALDO` |
| \(Q_5\) | `ENTREGA` |
| \(Q_6\) | `ESPERA_RESTART` |
| \(Q_7\) | `DEVOLUCION` |
| \(Q_8\) | `RETORNO_REPOSO` |

En un estado One-Hot válido, exactamente uno de estos bits está activo. `DECISION_SALDO` no se incluye: permanece reservado para la alternativa A y no pertenece al flujo de nueve estados de la alternativa B.

## Notación y condiciones

- \(Q_i^+\) representa el valor de \(Q_i\) después del siguiente flanco activo del reloj.
- \(R\) significa **S1 afirmado como reset lógico**. No fija la polaridad eléctrica ni si el reset es síncrono o asíncrono.
- `request_valid` es la solicitud válida mediante `START`; `restart_event` es el evento acondicionado de `RESTART`.
- `selected_available` y `selected_empty` son las condiciones de disponibilidad del producto capturado.
- `result_valid` y `negative` son las salidas registradas del restador. El signo solo se consume cuando `result_valid=1`.
- En las salidas de producto, `sel_A`, `sel_B` y `sel_C` denotan que `selected_product_reg` contiene, respectivamente, A, B o C. Son predicados de decodificación del producto capturado, no nuevas entradas externas.
- \(\kappa\) representa, solo como abreviatura matemática, la condición de que la captura de solicitud se haya completado. La interfaz no define una señal de confirmación independiente para esta condición.
- \(\rho_D\) y \(\rho_R\) representan, solo como abreviaturas matemáticas, las condiciones aún no especificadas de terminación de `DEVOLUCION` y de cierre de `RETORNO_REPOSO`. No son señales definidas ni se les asigna temporizador.
- Los términos marcados **pendientes** no deben implementarse como comportamiento decidido hasta que se aclare la transición correspondiente.
- Las ecuaciones de salida se presentan primero para operación normal, es decir, cuando S1 no está afirmado. Una posible inhibición durante reset se describe por separado y no fija la polaridad eléctrica ni la sincronía de S1.

Las ecuaciones de siguiente estado se expresan con prioridad de reset:

\[
Q_i^+ =
\begin{cases}
1, & R \text{ y } i=0\\
0, & R \text{ y } i\ne 0\\
F_i, & \neg R
\end{cases}
\]

Equivalentemente, \(Q_0^+=R\lor(\neg R\land F_0)\) y \(Q_i^+=\neg R\land F_i\) para \(i=1,\ldots,8\). En funcionamiento normal se asume un estado One-Hot válido; el comportamiento de estados ilegales no está especificado.

## Predecesores, permanencia y ecuaciones de siguiente estado

La columna de ecuación normal muestra los términos conocidos bajo \(\neg R\). Una ecuación se llama **parcial** cuando falta una transición necesaria para cubrir todos los casos posibles.

| Bit / estado | Predecesor(es) | Entrada y condición de transición | Permanencia | Ecuación normal \(F_i\), antes de aplicar prioridad de S1 |
|---|---|---|---|---|
| \(Q_0\) `REPOSO` | Inicio por S1; \(Q_6\); \(Q_8\) | Desde \(Q_6\): `restart_event`. Desde \(Q_8\): cierre de retorno, pendiente \(\rho_R\). | Permanece si no hay `request_valid`. | **Parcial:** \(F_0=(Q_0\land\neg request\_valid)\lor(Q_6\land restart\_event)\lor(Q_8\land\rho_R)\). El último término depende de una condición de cierre no definida. |
| \(Q_1\) `CAPTURA_SOLICITUD` | \(Q_0\); \(Q_1\) | Entrada desde `REPOSO` con `request_valid`. | Si la captura puede tardar varios ciclos, permanece mientras no se complete: \(Q_1\land\neg\kappa\). Si se elige un ciclo único, no hay lazo de permanencia. | **Parcial por decisión temporal:** \(F_1=(Q_0\land request\_valid)\lor(Q_1\land\neg\kappa)\). Si se adopta el ciclo único, se simplifica a \(F_1=Q_0\land request\_valid\); la duración de este estado aún debe decidirse. |
| \(Q_2\) `CARGA_Y_REVISION` | \(Q_1\) | Solicitud de producto e importe capturada (\(\kappa\)). | La propuesta usa este estado para el ciclo E0; la carga de operandos ocurre aquí. | \(F_2=Q_1\land\kappa\). Este término de entrada está definido por la condición de captura; decidir si \(\kappa\) se cumple en el ciclo de aceptación o después de varios ciclos determina la duración de \(Q_1\). |
| \(Q_3\) `LANZAR_CALCULO` | \(Q_2\) | `selected_available=1`. | Es un estado propuesto de un ciclo para emitir una sola solicitud de resta. | \(F_3=Q_2\land selected\_available\). |
| \(Q_4\) `CALCULO_SALDO` | \(Q_3\); \(Q_4\) | Desde \(Q_3\): lanzamiento de un ciclo. Desde \(Q_4\): `result_valid=0` mantiene la espera. Con `result_valid=1` y `negative=0` avanza a entrega. | La permanencia local \(Q_4\land\neg result\_valid\) está definida; con resultado válido se consume el resultado. | **Ecuación local de permanencia válida; siguiente estado global incompleto:** \(F_4=Q_3\lor(Q_4\land\neg result\_valid)\). Falta decidir el destino cuando \(Q_4\land result\_valid\land negative\); la fórmula no constituye una especificación completa de esa transición. |
| \(Q_5\) `ENTREGA` | \(Q_4\) | `result_valid=1` y `negative=0`. | Estado de acción propuesto de un ciclo; después pasa a espera de `RESTART`. | \(F_5=Q_4\land result\_valid\land\neg negative\). |
| \(Q_6\) `ESPERA_RESTART` | \(Q_5\); \(Q_6\) | Desde \(Q_5\): acción única de entrega completada. Desde \(Q_6\): `restart_event` inicia otra transacción. | Permanece mientras no ocurra `restart_event`. | \(F_6=Q_5\lor(Q_6\land\neg restart\_event)\). `RESTART` no activa el reset de inventarios. |
| \(Q_7\) `DEVOLUCION` | \(Q_2\); potencialmente \(Q_4\); \(Q_7\) | Desde \(Q_2\): `selected_empty`. Desde \(Q_4\), el caso `result_valid=1` y `negative=1` tiene destino pendiente. | La permanencia \(Q_7\land\neg\rho_D\) se expresa con un marcador de terminación aún no definido. | **Parcial:** términos conocidos/candidatos \(Q_2\land selected\_empty\) y \(Q_7\land\neg\rho_D\). El término desde \(Q_4\land result\_valid\land negative\) solo se añade si se acuerda esa ruta; \(\rho_D\) sigue pendiente. |
| \(Q_8\) `RETORNO_REPOSO` | \(Q_7\); \(Q_8\) | Desde \(Q_7\): terminación de devolución, \(\rho_D\). Desde \(Q_8\): cierre de retorno, \(\rho_R\). | La permanencia se representa únicamente como complemento de la condición de cierre no especificada; no se asigna temporizador. | **Parcial:** \(F_8=(Q_7\land\rho_D)\lor(Q_8\land\neg\rho_R)\). Ambos predicados requieren definición antes de fijar la ecuación. |

### Derivación paso a paso

1. **`REPOSO`:** la tabla especifica un lazo sin solicitud, una transición a captura al aceptar `request_valid` y un retorno desde `ESPERA_RESTART` al aceptar `restart_event`. El retorno desde `RETORNO_REPOSO` se representa con \(\rho_R\), pues su condición no está establecida.
2. **`CAPTURA_SOLICITUD` y `CARGA_Y_REVISION`:** `request_valid` lleva a \(Q_1\). La captura de producto e importe precede al uso de esos datos. Como el momento exacto de captura —al aceptar `START` o durante \(Q_1\)— sigue abierto, \(\kappa\) indica su finalización. Si \(Q_1\) puede durar varios ciclos, la permanencia es \(Q_1\land\neg\kappa\), y la entrada a \(Q_2\) ocurre cuando \(Q_1\land\kappa\). Si se adopta un ciclo único, se elimina el lazo y la decisión debe quedar explícita en la especificación.
3. **E0 y E1:** desde \(Q_2\), `selected_available` lleva a \(Q_3\); la disponibilidad agotada lleva a \(Q_7\). \(Q_3\) dura un ciclo y lleva a \(Q_4\), emitiendo `calculate_balance` solo en ese ciclo. Así precio y crédito se cargan en E0 antes del pulso calculado en E1.
4. **E2:** la permanencia local de \(Q_4\) cuando `result_valid=0` está correctamente representada por \(Q_4\land\neg result\_valid\). Cuando `result_valid=1` y `negative=0`, avanza a \(Q_5\); el vuelto se carga en ese mismo flanco. Aun cuando ese término local esté bien derivado, la FSM global sigue incompleta porque el caso `result_valid=1` y `negative=1` no tiene destino acordado. La ecuación de \(Q_7\) también queda parcial respecto a la posible ruta de pago insuficiente.
5. **Entrega y reinicio de transacción:** \(Q_5\) es el ciclo único para la indicación de entrega y un solo decremento del inventario seleccionado; luego \(Q_6\) espera `RESTART`. \(Q_6\) conserva su estado sin evento y vuelve a reposo al aceptar el evento, sin restaurar inventario.
6. **Devolución y retorno:** la transición hacia \(Q_7\) por producto agotado sí está identificada. La terminación de \(Q_7\) y el cierre de \(Q_8\) no lo están; \(\rho_D\) y \(\rho_R\) son marcadores de condiciones pendientes, no señales o temporizadores propuestos.

## Ecuaciones preliminares de salidas

Las siguientes ecuaciones usan el estado actual durante **operación normal** (\(\neg R\)). La clasificación Moore/Mealy y las dependencias de producto conservan las de la [tabla de salidas](./tabla_salidas_control_fsm.md). Estas ecuaciones no fijan por sí solas el comportamiento de las salidas cuando S1 está afirmado.

| Salida | Ecuación preliminar | Tipo | Derivación y condición |
|---|---|---|---|
| `capture_request` | \(capture\_request=Q_1\) | Moore | Activa durante `CAPTURA_SOLICITUD`; captura desde entradas sincronizadas y acondicionadas. Si \(Q_1\) dura varios ciclos, esta salida permanece activa durante ellos; debe definirse el flanco de captura y garantizar la estabilidad de producto e importe para evitar muestras repetidas o distintas. |
| `load_price` | \(load\_price=Q_2\) | Moore | Activa en `CARGA_Y_REVISION` para cargar el precio del producto ya capturado. |
| `load_credit` | \(load\_credit=Q_2\) | Moore | Activa junto con `load_price` en E0; `calculate_balance` sigue inactiva en ese ciclo. |
| `calculate_balance` | \(calculate\_balance=Q_3\) | Moore | El estado de un ciclo `LANZAR_CALCULO` genera el pulso único E1, después de cargar y estabilizar los operandos en E0. |
| `load_change` | \(load\_change=Q_4\land result\_valid\land\neg negative\) | Mealy | Solo en E2, si el resultado recién registrado es válido y no negativo; captura `magnitude` como vuelto. |
| `decrement_stock_A` | \(decrement\_stock_A=Q_5\land sel\_A\) | Mealy | Pulso único de un ciclo para actualizar el inventario A, condicionado al producto capturado; no se mantiene para prolongar el LED. |
| `decrement_stock_B` | \(decrement\_stock_B=Q_5\land sel\_B\) | Mealy | Pulso único de un ciclo para actualizar el inventario B, condicionado al producto capturado; no se mantiene para prolongar el LED. |
| `decrement_stock_C` | \(decrement\_stock_C=Q_5\land sel\_C\) | Mealy | Pulso único de un ciclo para actualizar el inventario C, condicionado al producto capturado; no se mantiene para prolongar el LED. |
| `clear_transaction` | \(clear\_transaction=Q_6\land restart\_event\) | Mealy | Limpia los registros temporales acordados al aceptar `RESTART`; no incluye los registros de inventario. |
| `delivery_led_A` | \(delivery\_led_A=Q_5\land sel\_A\) | Mealy | Indicación A asociada a `ENTREGA`; la duración visible necesita definición independiente del pulso de decremento. |
| `delivery_led_B` | \(delivery\_led_B=Q_5\land sel\_B\) | Mealy | Indicación B asociada a `ENTREGA`; la duración visible necesita definición independiente del pulso de decremento. |
| `delivery_led_C` | \(delivery\_led_C=Q_5\land sel\_C\) | Mealy | Indicación C asociada a `ENTREGA`; la duración visible necesita definición independiente del pulso de decremento. |
| `refund_indicator` | \(refund\_indicator=Q_7\) | Moore | Indica la permanencia en `DEVOLUCION`. No implica mecanismo físico, política de pago insuficiente ni duración determinada. |

La fila de reset de inventarios no se mezcla con las salidas ordinarias:

- **S1 afirmado:** la FSM toma el estado `REPOSO` con prioridad sobre cualquier transición normal. El requisito indica restaurar `inventory_A`, `inventory_B` e `inventory_C` a tres unidades; polaridad y sincronía del reset quedan pendientes.
- **`RESTART`:** solo puede ser aceptado en `ESPERA_RESTART`; puede activar `clear_transaction`, pero no restablece los inventarios.

Las ecuaciones de la tabla anterior son expresiones de operación normal. Si la implementación requiere suprimir las salidas de control mientras S1 está afirmado, puede usarse de manera provisional la forma \(y_{\mathrm{op}}=\neg R\land y_{\mathrm{normal}}\) para cada salida de operación \(y\). La acción de reset de inventario se maneja aparte y no se inhibe con esa expresión. Esta compuerta es una opción de interfaz lógica, no una decisión sobre polaridad eléctrica, reset síncrono/asíncrono ni adaptación a los módulos reutilizados. La tabla de salidas no prescribe reset explícito para los LEDs; su comportamiento durante S1 debe especificarse junto con la estrategia de reset.

## Límites de esta derivación

- La transición de pago insuficiente desde `CALCULO_SALDO` queda incompleta; no se inventa `CANCEL`.
- No se definen la condición de salida de `DEVOLUCION`, la permanencia de `RETORNO_REPOSO` ni temporizadores para esas rutas.
- La codificación de monedas y la captura de producto/importe deben aclararse; por ello, `request_valid`, `selected_available` y `selected_empty` dependen de una interfaz aún por precisar.
- Los LEDs de entrega se muestran con el pulso de `ENTREGA` en estas ecuaciones, pero su duración visible no está resuelta y no se asigna automáticamente un temporizador de 2 segundos.
- La contradicción entre mostrar el vuelto y la instrucción de no conectar el bloque de despliegue no se resuelve en estas ecuaciones.
- Las ecuaciones locales de permanencia o de transición pueden estar correctamente derivadas para las condiciones que cubren sin que la FSM completa esté definida. En particular, el término de permanencia de \(Q_4\) es válido, pero falta una transición para el resultado válido negativo.
- Las ecuaciones parciales y el conjunto actual no deben implementarse como si la FSM ya estuviera completamente definida. Antes de implementar, deben completarse las transiciones pendientes, validar prioridades y especificar las condiciones de frontera.

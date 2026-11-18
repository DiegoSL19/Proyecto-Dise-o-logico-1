# Ecuaciones One-Hot de la FSM

Las ecuaciones describen vending_fsm.sv para estados One-Hot válidos y señales binarias. El estado, las transiciones y las salidas se implementan en tres bloques separados. La aritmética y los registros de importes e inventarios pertenecen a la ruta de datos.

## Codificación y notación

| Bit | Estado |
|---|---|
| Q0 | REPOSO |
| Q1 | CAPTURA_SOLICITUD |
| Q2 | CARGA_Y_REVISION |
| Q3 | LANZAR_CALCULO |
| Q4 | CALCULO_SALDO |
| Q5 | ENTREGA |
| Q6 | ESPERA_RESTART |
| Q7 | DEVOLUCION |
| Q8 | RETORNO_REPOSO |

AND significa conjunción; OR, disyunción; NOT, negación.

| Símbolo | Señal |
|---|---|
| R | reset lógico activo alto |
| E | request_event |
| S | selection_valid |
| A | selected_available |
| V | result_valid |
| P | purchase_authorized |
| N | negative |
| T | restart_event |

P requiere producto válido, inventario disponible, resultado válido y signo no negativo. Las expresiones mantienen V y P explícitos para reflejar las condiciones exactas del RTL.

## Siguiente estado

Para operación sin reset:

| Estado | Fi |
|---|---|
| Q0 | (Q0 AND NOT E) OR (Q6 AND T) OR Q8 |
| Q1 | Q0 AND E |
| Q2 | Q1 OR (Q2 AND NOT S) |
| Q3 | Q2 AND S AND A |
| Q4 | Q3 OR (Q4 AND NOT(V AND P) AND NOT(V AND N)) |
| Q5 | Q4 AND V AND P |
| Q6 | Q5 OR (Q6 AND NOT T) |
| Q7 | (Q2 AND S AND NOT A) OR (Q4 AND V AND NOT P AND N) |
| Q8 | Q7 |

Con prioridad de reset, Q0 siguiente = R OR (NOT R AND F0). Para i entre 1 y 8, Qi siguiente = NOT R AND Fi.

NOT P en la entrada a Q7 conserva la prioridad de autorización sobre signo negativo. La permanencia de Q4 incluye el caso V=1, P=0 y N=0.

Un código que no coincide con los nueve valores enumerados activa default: siguiente estado REPOSO y salidas inactivas. Fi presupone un estado One-Hot válido y no sustituye esa recuperación.

## Salidas

Cada expresión se habilita además con NOT R.

| Señal | Expresión en operación normal |
|---|---|
| capture_credit | Q0 AND E |
| load_selection | Q1 |
| load_price | Q2 AND S AND A |
| load_credit | Q2 AND S AND A |
| calculate_balance | Q3 |
| load_change | Q4 AND V AND P |
| decrement_A | Q5 AND S AND producto=00 |
| decrement_B | Q5 AND S AND producto=01 |
| decrement_C | Q5 AND S AND producto=10 |
| refund_active | Q7 |
| clear_transaction | (Q6 AND T) OR Q8 |

Las igualdades de producto decodifican el registro capturado. La suficiencia monetaria se obtiene del signo de la resta.

## Temporalidad y presentación

Las cargas se consumen en E0, el cálculo en E1 y el vuelto en E2. El decremento se consume al salir de Q5. RESTART se acepta en Q6; Q7 y Q8 cierran automáticamente una devolución.

Los indicadores persistentes están en el wrapper. LED de entrega y display decimal permanecen habilitados hasta limpiar la transacción. El LED de devolución usa un temporizador independiente de dos segundos; no prolonga refund_active ni los decrementos.

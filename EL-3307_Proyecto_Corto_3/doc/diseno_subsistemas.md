# Diseño preliminar de subsistemas

## Propósito y alcance

Este documento propone una descomposición funcional inicial para la máquina expendedora del Proyecto Corto 3. Su objetivo es facilitar la revisión de interfaces, señales de control y registros antes de elaborar el diagrama de estados y la arquitectura definitiva. **No es una arquitectura aprobada ni una especificación de implementación.**

Se usan dos etiquetas para distinguir la fuente de cada punto:

- **Requisito explícito:** indicado en el enunciado oficial.
- **Propuesta/pendiente del grupo:** opción preliminar que requiere análisis, justificación en la bitácora o aprobación del profesor cuando afecta una ambigüedad del enunciado.

Como referencia teórica se considera Harris y Harris, *Digital Design and Computer Architecture, ARM Edition*, especialmente las secciones 3.5 (*Timing of Sequential Logic*) y 4.9 (*Testbenches*). La primera orienta el razonamiento sobre registros y temporización síncrona; la segunda, la elaboración de bancos de prueba. Se usan como marco conceptual, no como sustituto de los requisitos del curso.

## Requisitos explícitos identificados

El enunciado oficial establece, entre otros puntos:

- Sistema síncrono para la Tang Nano 9K con un único reloj de 27 MHz.
- Entradas `PROD_SEL`, `IN_COINS`, `START` y `RESTART`; el botón S1 actúa como reset global.
- Tres productos con precios de ₡150, ₡275 y ₡400, y tres unidades iniciales de inventario por producto.
- FSM principal codificada One-Hot. Deben presentarse su diagrama, tabla de transición y ecuaciones de siguiente estado y de salida; las operaciones de la ruta de datos no se ejecutan dentro de la FSM.
- Ruta de datos con registros de precio e inventario y lógica síncrona para crédito, faltante y vuelto. El control debe indicar operaciones como cargar precio, cargar monto, calcular vuelto y disminuir inventario.
- La suficiencia de crédito debe determinarse a partir del signo de una resta, no mediante un operador de comparación.
- Cada base de tiempo más lenta, incluidos los temporizadores de 2 s, debe derivarse del único reloj mediante divisores que produzcan pulsos de habilitación.
- La sección de despliegue describe cuatro displays, pero concluye con «No conecte este bloque».

La fuente principal es el enunciado oficial, [`Proyectos_Proyecto-Corto-3-II-Semestre-2026.pdf`](./Proyectos_Proyecto-Corto-3-II-Semestre-2026.pdf). Su texto contiene además contradicciones entre la interfaz de monedas y los escenarios de verificación, y entre el requisito de despliegue y la instrucción de no conectar el bloque; no se resuelven aquí.

## Bloques funcionales propuestos

El flujo preliminar sería:

`PROD_SEL, IN_COINS, START, RESTART, S1 → acondicionamiento y captura → FSM ↔ ruta de datos → LEDs de estado`

La ruta de datos proveería también `change_bin` hacia una posible ruta de despliegue. Esta última se mantiene aislada y desconectada hasta que el profesor aclare el requisito del display.

### Interfaces por bloque

| Bloque | Entradas | Salidas | Clasificación y observaciones |
|---|---|---|---|
| Acondicionamiento de entradas | Pines de `PROD_SEL`, `IN_COINS`, `START`, `RESTART`, `S1`; `clk`, reset de acondicionamiento | Señales sincronizadas y, cuando corresponda, filtradas; eventos de pulsación | **Requisito explícito:** sincronizar entradas externas y eliminar rebotes. **Propuesta:** sincronizar señales asíncronas y aplicar antirrebote principalmente a botones; confirmar el tratamiento de los DIP switches y la polaridad eléctrica. |
| Captura/decodificación de solicitud | Señales acondicionadas de producto, monedas y `START` | `start_event`, `selected_product`, `coin_input_value` o valor equivalente, `request_valid` | **Requisito explícito:** los DIP seleccionan producto y cantidad de monedas; `START` confirma selección e ingreso. **Pendiente:** ancho, codificación y momento exacto de captura de `IN_COINS`. |
| FSM principal One-Hot | `clk`, `reset`, eventos de entrada, condiciones de la ruta de datos, expiraciones de habilitación/temporizador | Señales de control a la ruta de datos; estados/indicaciones para LEDs | **Requisito explícito:** FSM One-Hot y separación entre control y operaciones aritméticas/registros. Los nombres de estados y la secuencia concreta siguen pendientes. |
| Ruta de datos aritmética e inventario | Valores de solicitud, señales de control de la FSM, `clk`, `reset` | `selected_available`, `credit_sufficient`, `underpayment`, `change_ready`, `change_bin`, condición de inventario agotado | **Requisito explícito:** operaciones y registros síncronos controlados por la FSM; precios e inventario especificados. Anchos, habilitaciones, reglas de crédito y momento de actualización del inventario deben decidirse. |
| Base de tiempo y temporizadores | `clk`, `reset`, parámetros de divisores y habilitaciones de la FSM | Pulsos `tick_scan`, `tick_display` (si se usa) y una o más condiciones `timer_done` | **Requisito explícito:** un reloj y pulsos de habilitación derivados; se mencionan temporizadores de 2 s. **Pendiente:** qué acciones temporizar, cuántos temporizadores y si son comunes o independientes. |
| Indicadores de salida | Estado FSM e inventarios | LEDs de entrega A/B/C, LEDs de agotado A/B/C y señal/LED de devolución | **Requisito explícito:** LEDs particulares para entrega y agotamiento; indicación de devolución. **Pendiente:** si las señales son pulsos o niveles mantenidos y durante cuánto tiempo. |
| Conversión y despliegue | `change_bin`, habilitación de refresco, `clk`, reset | Señales de segmentos, selección de dígito y puntos decimales | **Requisito explícito contradictorio:** mostrar vuelto en cuatro displays y «No conecte este bloque». **Propuesta:** desarrollar la interfaz de manera aislada, pero dejar el bloque desconectado en la integración hasta aclaración. |

### Señales de control de la FSM hacia la ruta de datos

Los nombres siguientes son descriptivos y **propuestos**, no nombres exigidos por el enunciado.

| Señal propuesta | Acción en la ruta de datos | Cuándo podría activarse |
|---|---|---|
| `load_price` | Cargar en `price_reg` el precio asociado al producto seleccionado | Al aceptar/capturar una solicitud válida |
| `load_credit` | Cargar el importe ingresado o el primer importe reconocido en `credit_reg` | Tras confirmar la entrada de monedas |
| `add_credit` | Acumular importe adicional en `credit_reg` | Si el protocolo elegido admite varias cargas |
| `clear_transaction` | Limpiar registros temporales de la transacción, sin borrar inventario | Al iniciar una nueva transacción o al completar una devolución, según la secuencia acordada |
| `calculate_balance` | Solicitar la resta entre crédito y precio para establecer suficiencia y/o vuelto | Una vez cargados precio y crédito |
| `load_change` | Registrar el monto a devolver en `change_reg` | Tras confirmar crédito suficiente y cálculo válido |
| `load_refund` | Registrar el crédito total que debe devolverse en `refund_reg` | En una cancelación o producto agotado, según política aprobada |
| `decrement_stock_A/B/C` | Disminuir en una unidad el inventario del producto entregado | Solo cuando se confirme la entrega correspondiente |
| `clear_temp` | Limpiar estados temporales del cálculo | Al cerrar o reiniciar una transacción, si se requiere aparte de `clear_transaction` |

**Propuesta de pulso:** las órdenes de carga, cálculo y decremento serían habilitaciones de un ciclo de `clk`, y el bloque ejecutaría la operación en el flanco activo. Debe definirse una única señal de carga/decremento por evento para evitar actualizaciones repetidas mientras la FSM permanece en un estado.

### Señales de condición desde la ruta de datos hacia la FSM

| Señal propuesta | Significado |
|---|---|
| `request_valid` / `start_event` | Hay una solicitud nueva ya acondicionada y capturada |
| `product_A`, `product_B`, `product_C` | Código de producto decodificado o selección registrada |
| `selected_available` | El inventario del producto seleccionado es mayor que cero |
| `selected_empty` | El inventario del producto seleccionado es cero |
| `balance_valid` | El resultado de la resta está registrado y puede consumirse |
| `credit_sufficient` | El signo de la resta seleccionada indica que el crédito cubre el precio |
| `underpayment` | El signo de la resta indica que el crédito no cubre el precio |
| `change_ready` | El registro de vuelto contiene un resultado válido |
| `refund_ready` | El registro de devolución contiene el monto acordado |
| `inventory_empty_A/B/C` | El inventario correspondiente llegó a cero |
| `restart_event` | `RESTART` se detectó como evento válido |
| `timer_done` | Terminó el intervalo temporizado habilitado por la FSM |

`credit_sufficient` y `underpayment` son conceptualmente complementarias para una transacción válida, pero la FSM debería aceptar la decisión solo cuando `balance_valid` esté activo. El nombre de la bandera de signo dependerá de la convención elegida al conectar el restador.

## Registros propuestos para la ruta de datos

Los anchos concretos deben justificarse en la bitácora y verificarse para todas las operaciones y codificaciones elegidas.

| Registro | Contenido y función | Carga/actualización propuesta |
|---|---|---|
| `selected_product_reg` | Producto asociado a la transacción actual | Captura sincronizada al aceptar `START` |
| `price_reg` | ₡150, ₡275 o ₡400 según el producto | `load_price` |
| `credit_reg` | Crédito acumulado o importe confirmado para la transacción | `load_credit`, `add_credit`; limpieza al cerrar la transacción |
| `balance/magnitude` y `negative` | Resultado absoluto y signo de la resta crédito-precio, si se reutiliza el restador validado | Actualizados al solicitar un cálculo |
| `change_reg` | Crédito excedente que debe mostrarse/devolverse | `load_change` cuando la operación es suficiente |
| `refund_reg` | Total de crédito a devolver en cancelación o rechazo por agotamiento | `load_refund`, según la política que se defina |
| `inventory_A_reg`, `inventory_B_reg`, `inventory_C_reg` | Unidades restantes de cada producto; inicializadas a 3 | Reset global las inicializa; entrega confirmada disminuye el registro correspondiente |
| `timer_counter` o contadores de tiempo | Cuenta de ciclos/ticks para acciones temporizadas | Incremento con habilitación y reinicio/paro según el diseño del temporizador |

**Decisión aritmética preliminar:** una operación `credit_reg - price_reg` permite interpretar el signo negativo como pago insuficiente y, cuando el crédito alcanza o supera el precio, la magnitud como vuelto. Para crédito exactamente igual al precio, la magnitud es cero y la resta no es negativa. Esta orientación debe documentarse junto con el formato y ancho de cada operando; no determina cómo se reciben las monedas ni cómo se devuelve el importe insuficiente.

## Reutilización de módulos validados en el Proyecto Corto 2

Los resultados existentes son pruebas RTL individuales de los módulos originales; no prueban su integración ni su adecuación automática al nuevo diseño. El detalle de los casos y sus limitaciones está en [`validacion_modulos_reutilizables.md`](./validacion_modulos_reutilizables.md).

| Módulo reutilizable | Posible función en esta propuesta | Adaptación/limitación que debe revisarse |
|---|---|---|
| `synchronizer.sv` | Sincronizar entradas asíncronas antes de lógica síncrona | La instancia validada tiene entrada de cuatro bits y reset sincrónico activo en alto, con valor de reset `1111`; revisar ancho, polaridad y valores de reposo de cada entrada real. |
| `debouncer.sv` | Filtrar `START`, `RESTART` y, si corresponde, otros contactos mecánicos | El testbench usó `N=4`; dimensionar el parámetro para el reloj y el tiempo de rebote objetivo. Confirmar polaridad de entrada/reset y formar eventos de pulsación sin repeticiones. |
| `tick_generator.sv` | Producir habilitaciones periódicas para escaneo/actualización y base de temporizadores | Las pruebas usaron divisores 4 y 3; definir divisores de producción. Confirmar la fase, el período y si hacen falta habilitaciones adicionales para los temporizadores de 2 s. Mantener el único dominio de reloj. |
| `subtractor.sv` | Calcular `credit - price` y proporcionar magnitud y signo para la suficiencia y el vuelto | Tiene operandos y magnitud de 10 bits y salida registrada; coordinar `calculate`/`result_valid`, fijar la orientación de operandos y revisar rango y representación. La simulación aislada no demuestra su compatibilidad con los registros propuestos. |
| `bcd_converter.sv` | Convertir un monto binario a tres dígitos BCD para un posible despliegue | Depende de `rom_reg.sv` y `bcdtable.txt`; la tabla validada transforma 1000 en `000` y no entrega cuatro dígitos. Confirmar rango del vuelto y si se permite usarlo dado el requisito de desconectar el despliegue. |
| `disp_hex_mux.sv` | Multiplexar cuatro dígitos y generar segmentos y puntos decimales | Sus pruebas usaron `N=4`; ajustar el refresco para hardware y confirmar polaridades/pines. **Mantenerlo desconectado en el Proyecto Corto 3 hasta que el profesor aclare «No conecte este bloque».** |

## Secuencia de operación conceptual

La siguiente secuencia es una ayuda para el diseño, no una lista aprobada de estados:

1. Reposo, a la espera de una solicitud.
2. Captura de producto y entrada de monedas al confirmar `START`.
3. Selección/carga del precio y consulta del inventario.
4. Si hay inventario, cálculo de crédito menos precio y decisión a partir del signo.
5. Si el crédito alcanza el precio, carga del vuelto, señalización de entrega y decremento único del inventario.
6. Espera de `RESTART` para iniciar una transacción nueva sin borrar inventario.
7. En pago insuficiente, cancelación o producto agotado, ejecutar la ruta de devolución que se apruebe.

La subdivisión, duración y prioridad entre estados, reset global y entradas de usuario se deben determinar al construir el diagrama de estados y la tabla de transición.

## Decisiones de diseño pendientes

Antes de fijar interfaces y estados, el grupo debería resolver o consultar:

1. **Representación de `IN_COINS`:** el enunciado lo describe como cantidad de monedas de ₡100, pero sus escenarios requieren también ₡50 y ₡25. ¿Se cambia la interfaz, se interpreta el DIP como importe codificado o se usa otra representación? ¿Cuál es el ancho y la codificación?
2. **Crédito de la transacción:** ¿el importe se ingresa una sola vez con `START` o hay una secuencia de cargas/monedas? ¿Qué significa “acumular crédito” en relación con el DIP?
3. **Pago insuficiente y cancelación:** ¿se devuelve automáticamente el crédito insuficiente o se espera una entrada explícita de cancelación? ¿Cómo se conserva y presenta el importe devuelto?
4. **Devolución por producto agotado:** ¿se devuelve el monto indicado en `IN_COINS` aunque no haya una compra previa en curso? ¿Qué estado/LED indica esa acción y durante cuánto tiempo?
5. **Bloque de display:** la instrucción «No conecte este bloque» contradice el requisito de mostrar el vuelto. ¿Se debe dejar sin conexión en la integración, aun cuando se diseñe y simule por separado, o se espera otra interpretación?
6. **Temporizadores de 2 s:** ¿qué eventos o estados deben durar 2 s? ¿Cuántos temporizadores se requieren y qué ocurre si cambia una entrada durante la cuenta?
7. **Señalización:** ¿los LEDs de entrega y devolución son pulsos temporizados o permanecen activos hasta `RESTART`? ¿Los LEDs de agotado se derivan continuamente del inventario o se registran?
8. **Reset y reinicio:** confirmar polaridad y sincronía del botón S1. El enunciado distingue el reset global que restaura inventarios de `RESTART`, que no debe borrarlos; definir también el estado de cada salida durante el reset.
9. **Rangos y aritmética:** justificar ancho, unidad, signo y límites para precio, crédito, faltante, vuelto y códigos de inventario; confirmar cómo se representa un crédito exacto y los montos máximos.
10. **Integración física:** confirmar asignación de pines, polaridades, niveles eléctricos y configuración de pull-up/pull-down antes de conectar señales a la Tang Nano 9K.

## Próximos artefactos de diseño

Una vez aclaradas las decisiones relevantes, el grupo puede fijar el diagrama de bloques y las interfaces, justificar los anchos de palabra, elaborar el diagrama/tabla/ecuaciones de la FSM One-Hot y derivar escenarios de prueba RTL. Las decisiones tomadas y sus cálculos deben quedar documentados en la bitácora. Este documento no reemplaza esos artefactos ni declara validada la integración.


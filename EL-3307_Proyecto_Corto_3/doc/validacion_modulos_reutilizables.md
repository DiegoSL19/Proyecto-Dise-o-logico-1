# Validación RTL de módulos reutilizables

## Alcance

Se registran los resultados de simulaciones RTL ejecutadas con Icarus Verilog para cuatro módulos del Proyecto Corto 2, considerados como candidatos a reutilización en el Proyecto Corto 3. Las pruebas se realizaron con los testbenches unitarios indicados en cada sección.

Estos resultados corresponden a los módulos originales del Proyecto Corto 2. Verifican los casos descritos a continuación de forma aislada y **no demuestran todavía el funcionamiento integrado de estos módulos en el Proyecto Corto 3**.

## Resultados resumidos

| Módulo | Pruebas | Errores | Resultado |
|---|---:|---:|---|
| `synchronizer.sv` | 18 | 0 | PASS |
| `debouncer.sv` | 72 | 0 | PASS |
| `tick_generator.sv` | 42 | 0 | PASS |
| `subtractor.sv` | 17 | 0 | PASS |

## `synchronizer.sv`

- **Función:** sincronizar con `clk` una entrada asíncrona de cuatro bits mediante dos etapas de registros.
- **Señales principales:** `clk`, `reset` (sincrónico y activo en alto), `async_in[3:0]` y `sync_out[3:0]`. Ambas etapas se inicializan a `4'b1111` mientras el reset está activo.
- **Testbench:** `EL-3307_Proyecto_Corto_2/src/sim/tb_synchronizer.sv` (`tb_synchronizer`), con reloj de prueba de aproximadamente 27 MHz.
- **Condiciones comprobadas:** valor inicial y reset; ausencia de cambio inmediato ante una entrada nueva; conservación del valor anterior en el primer flanco después del cambio; entrega del nuevo valor después del segundo flanco; respuesta al reset únicamente en el flanco positivo; y sincronización de una nueva entrada después de liberar el reset.
- **Resultado:** 18 pruebas, 0 errores; **PASS**.
- **Limitaciones:** se comprobaron unos pocos patrones de cuatro bits y secuencias dirigidas. La simulación RTL no modela ni mide la probabilidad de metastabilidad, no cubre todas las posibles entradas y temporizaciones asíncronas y no valida la integración con las señales de la placa o del Proyecto Corto 3.

## `debouncer.sv`

- **Función:** filtrar cambios breves de una entrada de botón y actualizar la salida cuando la entrada sincronizada se mantiene estable durante el intervalo definido por el contador parametrizado.
- **Señales principales:** `clk`, `n_reset` (sincrónico y activo en bajo), `button_in` y `DB_out`; el módulo también recibe el parámetro `N`, que determina el contador de estabilidad.
- **Testbench:** `EL-3307_Proyecto_Corto_2/src/sim/tb_debouncer.sv` (`tb_debouncer`), con reloj de prueba de aproximadamente 27 MHz y `N=4` (ocho ciclos de estabilidad en esta prueba, no el valor predeterminado del módulo).
- **Condiciones comprobadas:** reset activo y liberado; secuencias alternadas de rebote de menos de dos ciclos por nivel sin cambios prematuros en la salida; pulsación y liberación estables; un solo cambio de salida para cada transición estable; y comportamiento del reset sincrónico, incluida la limpieza de la salida.
- **Resultado:** 72 pruebas, 0 errores; **PASS**.
- **Limitaciones:** el parámetro reducido acorta deliberadamente la simulación y no verifica el intervalo de estabilidad del valor predeterminado ni otros valores de `N`. Se probaron secuencias dirigidas, no perfiles de rebote de botones físicos ni todas las secuencias posibles. Tampoco se validaron temporización física ni integración en el Proyecto Corto 3.

## `tick_generator.sv`

- **Función:** generar pulsos de habilitación de un ciclo para el barrido del teclado y la actualización del display a partir de un único reloj.
- **Señales principales:** `clk`, `reset` (sincrónico y activo en alto), `tick_keypad` y `tick_display`. Los parámetros `KEYPAD_DIV` y `DISPLAY_DIV` establecen los periodos en ciclos de reloj.
- **Testbench:** `EL-3307_Proyecto_Corto_2/src/sim/tb_tick_generator.sv` (`tb_tick_generator`), con reloj de prueba de aproximadamente 27 MHz y divisores reducidos `KEYPAD_DIV=4` y `DISPLAY_DIV=3`.
- **Condiciones comprobadas:** salidas inactivas durante el reset inicial y durante un reset aplicado a mitad de cuenta; periodos de 4 y 3 ciclos; duración de un ciclo de cada pulso y ceros entre pulsos; coincidencias periódicas de ambos ticks; y reinicio de fase y periodos después de liberar el reset.
- **Resultado:** 42 pruebas, 0 errores; **PASS**.
- **Limitaciones:** los divisores reducidos permiten comprobar los contadores en una simulación corta, pero no verifican los divisores predeterminados ni la frecuencia real de operación en la placa. Tampoco se comprobó el comportamiento del sistema que consume los ticks ni su integración en el Proyecto Corto 3.

## `subtractor.sv`

- **Función:** calcular la diferencia entre dos operandos sin signo y entregar por separado su magnitud y su signo.
- **Entradas:** `clk`, `reset` (sincrónico y activo en alto), `calculate`, `operand_a[9:0]` y `operand_b[9:0]`.
- **Salidas:** `magnitude[9:0]` es la magnitud no negativa de la diferencia; `negative` vale 1 cuando `operand_a < operand_b` y 0 cuando `operand_a >= operand_b`; `result_valid` indica que se solicitó un cálculo en el flanco actual. `magnitude` y `negative` son salidas registradas: se actualizan con `calculate` y se limpian con `reset`. Si `calculate` está bajo sin reset, conservan sus valores, mientras `result_valid` vuelve a 0.
- **Testbench:** `EL-3307_Proyecto_Corto_2/src/sim/tb_subtractor.sv` (`tb_subtractor`), con reloj de prueba de aproximadamente 27 MHz.
- **Operaciones y condiciones comprobadas:** restas con A mayor que B (`500-123`, `999-0`, `1-0`); A menor que B (`123-500`, `0-999`, `0-1`); operandos iguales (`123-123`); que la magnitud sea positiva independientemente del orden de los operandos; que `negative` distinga si el resultado matemático tiene signo negativo; que el resultado registrado se conserve al cambiar operandos sin volver a activar `calculate`; y que el reset tenga prioridad sobre `calculate` y limpie las salidas válidas.
- **Resultado:** 17 pruebas, 0 errores; **PASS**.
- **Limitaciones de reutilización:** la prueba ejercitó valores de hasta 999, pero no todas las combinaciones posibles del rango de 10 bits ni los límites superiores. Al reutilizarlo en el Proyecto Corto 3, se debe confirmar que los operandos y resultados caben en 10 bits, conectar A y B con el orden que corresponda a la operación deseada e interpretar `magnitude` junto con `negative` (la magnitud no tiene signo por sí sola). La FSM también debe coordinar `calculate` y `result_valid` con el registro del resultado. Esta prueba unitaria no valida esa adaptación ni la integración del módulo en el Proyecto Corto 3.

## Referencia teórica

Harris y Harris, *Digital Design and Computer Architecture, ARM Edition*, secciones 3.5 y 4.9. Se citan como referencia teórica sobre diseño digital secuencial y descripción/verificación mediante HDL; no sustituyen los resultados experimentales indicados en este documento.

## Límites de los resultados

Los resultados reportados son exclusivamente de simulación RTL de los cuatro módulos originales y sus testbenches unitarios. No se reportan resultados de síntesis, pruebas físicas en la Tang Nano 9K ni simulaciones post-síntesis o post-ruteo. La compatibilidad y el comportamiento integrado de estos módulos en el Proyecto Corto 3 quedan pendientes de verificación.

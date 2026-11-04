# Arquitectura general

## Objetivo

Describir los requisitos de una máquina expendedora síncrona de tres productos para la FPGA Tang Nano 9K. El sistema recibe la selección de producto y el monto de monedas indicado, decide si puede realizar la compra, señala la entrega o devolución correspondiente y muestra el vuelto en cuatro displays de siete segmentos.

La arquitectura debe separar claramente la **unidad de control**, implementada mediante una FSM principal, de la **ruta de datos** que registra inventarios y montos y realiza los cálculos de crédito, faltante y vuelto. Las operaciones de la ruta de datos no deben ejecutarse dentro de la FSM.

## Plataforma

- **Tarjeta:** Sipeed Tang Nano 9K.
- **Reloj:** señal de reloj de 27 MHz de la tarjeta. Se permite un único reloj para todo el sistema.
- **Temporización:** las bases de tiempo más lentas, incluidas las asociadas al barrido del teclado, al refresco de los displays y a temporizadores de 2 s de la FSM, deben obtenerse del reloj principal mediante divisores que generen pulsos de habilitación, no mediante relojes adicionales.
- **Diseño síncrono:** las señales externas deben sincronizarse con el reloj interno y sus posibles rebotes deben eliminarse. Los subsistemas deben registrarse adecuadamente en entradas y salidas y el flujo de datos debe quedar explícito.
- **Reset global:** el botón S1 de la Tang Nano 9K restablece los registros de inventario además del estado del sistema.

El enunciado no especifica la asignación de pines ni la polaridad eléctrica de las entradas y salidas. Deben verificarse contra la tarjeta antes de la integración física.

## Subsistemas

1. **Lectura de producto y monedas**
   - Lee `PROD_SEL`, que selecciona A, B o C, e `IN_COINS`, que indica la cantidad de monedas ingresadas.
   - `START` indica que se han seleccionado el producto y las monedas.
   - `RESTART` devuelve el sistema a su estado inicial al terminar el proceso, sin borrar el inventario.
   - Las entradas externas se sincronizan y se les elimina el rebote cuando corresponda.

2. **Control: FSM principal**
   - Controla la secuencia de la máquina y genera las señales de control para los registros y operaciones de la ruta de datos.
   - El enunciado exige codificación de estados One-Hot y solicita diagrama de estados, tabla de transiciones y ecuaciones de siguiente estado y de salida.
   - Las operaciones aritméticas y las actualizaciones de registros pertenecen a la ruta de datos, no a la FSM.
   - Según el enunciado, los comentarios del bloque de control en SystemVerilog deben escribirse en alemán.

3. **Ruta de datos aritmética**
   - Mantiene un registro de precio asociado al producto seleccionado, un registro de disponibilidad para cada producto y registros/lógica para el monto ingresado, el monto faltante y el vuelto.
   - Actualiza estos datos sincrónicamente bajo señales de control de la FSM, tales como cargar el precio y el monto, calcular el vuelto y disminuir el inventario.
   - El operador `+` puede acumular crédito y el operador `-` puede calcular faltantes o vueltos en complemento a dos. La condición de crédito suficiente debe determinarse a partir del signo de la resta, no mediante un operador de comparación.
   - El ancho de los registros queda a criterio del grupo y debe justificarse en la bitácora.

4. **Despliegue**
   - Recibe el vuelto en código binario y lo muestra en decimal en cuatro displays de siete segmentos, reutilizando el sistema de refresco del proyecto anterior.
   - La presentación del código de producto y del monto ingresado en los displays es un apartado extra, no un requisito base.

### Productos e inventarios

| Selección | Producto | Precio | Inventario inicial |
|---|---|---:|---:|
| A | Producto A | ₡150 | 3 unidades |
| B | Producto B | ₡275 | 3 unidades |
| C | Producto C | ₡400 | 3 unidades |

- El inventario de cada producto se restablece a 3 con el reset global S1.
- El inventario de un producto disminuye con cada entrega de ese producto; `RESTART` no altera el inventario.
- Al agotarse un producto, se enciende su LED particular de agotado.
- Si se selecciona un producto agotado, el sistema regresa al reposo y enciende un LED que indica la devolución de todas las monedas ingresadas.
- Si el crédito alcanza o supera el precio, se enciende el LED de entrega correspondiente y el display indica el monto de vuelto.
- Después de la entrega, se debe presionar `RESTART` para iniciar de nuevo sin alterar el inventario.
- Si el monto es insuficiente, el enunciado indica regresar al inicio y devolver todas las monedas. El escenario de prueba de pago insuficiente, sin embargo, también indica cancelar; la relación entre esa cancelación y la devolución se señala en «Ambigüedades y contradicciones».

### Temporizadores

El enunciado requiere temporizadores de 2 s asociados a la FSM. También indica que el barrido del teclado y el refresco del display se deriven del reloj de 27 MHz usando pulsos de habilitación. No se especifica qué estados o acciones de la FSM deben durar 2 s ni cuántos temporizadores independientes se requieren.

### Requisitos de la FSM y documentación del diseño

- La FSM principal debe usar codificación de estados **One-Hot**.
- La descripción de cada FSM debe separar el registro de estado, la lógica combinacional de siguiente estado y la lógica combinacional de salidas. Se deben definir los estados con `typedef enum` y establecer explícitamente el estado de reset.
- La lógica combinacional debe asignar sus salidas y señales en todos los caminos para prevenir la inferencia de latches.
- Para la FSM principal se deben presentar el diagrama de estados, la tabla de transiciones y las ecuaciones de siguiente estado y de salidas.
- Las señales de control que conectan la FSM con cada bloque de la ruta de datos deben identificarse claramente. Para cada FSM se deben presentar su diagrama de estados y las señales de control que maneja; no es necesario detallar la implementación interna de cada FSM adicional.
- Los comentarios dentro del bloque de control SystemVerilog deben escribirse en alemán.

### Verificación y escenarios obligatorios

Se deben presentar simulaciones de cada subsistema a nivel RTL (pre-síntesis) y con información de temporizado post-síntesis y post-colocación y ruteo. Las simulaciones se presentarán al asistente durante el horario de consulta. El testbench de la FSM principal debe cubrir, como mínimo, estos cuatro escenarios de la sección 4.5.3:

1. **Pago exacto:** producto A, pago descrito como ₡100 + ₡50; se entrega el producto y el vuelto es ₡0.
2. **Sobrepago:** producto A, pago de ₡100 + ₡100; se entrega el producto y el vuelto es ₡50.
3. **Pago insuficiente:** producto C, pago descrito como ₡100 + ₡25 y luego cancelación; se devuelven ₡125.
4. **Producto agotado:** después de tres compras del producto A, el sistema indica que se agotó. Si se selecciona A de nuevo, inicia el proceso de devolución de todas las monedas y vuelve al estado inicial sin borrar el inventario.

El enunciado recomienda parametrizar los divisores de frecuencia y usar valores reducidos en el testbench para que la simulación de los temporizadores sea práctica. Las denominaciones de los escenarios anteriores se transcriben tal como aparecen en el enunciado; la incompatibilidad con la entrada `IN_COINS` se conserva en «Ambigüedades y contradicciones».

### Bitácora

Cada integrante debe llevar una bitácora individual y manual de avance, con mediciones, cálculos, diseños y simulaciones a su cargo. Las hojas deben estar numeradas y fechadas. El asistente revisará y firmará la bitácora al menos una vez por semana; el profesor o el asistente podrán utilizarla para evaluar el trabajo individual.

## Entradas

- `PROD_SEL`: selección entre los productos A, B y C mediante un DIP switch.
- `IN_COINS`: cantidad de monedas de ₡100 indicada mediante un DIP switch, según la descripción de la interfaz del enunciado.
- `START`: botón que confirma la selección del producto y el ingreso de monedas.
- `RESTART`: botón que devuelve la máquina a su estado inicial tras completar el proceso, sin restablecer el inventario.
- `S1`: botón de reset global de la Tang Nano 9K; restablece los registros de inventario.
- **Reloj de 27 MHz:** reloj único del sistema.

El enunciado no especifica el ancho ni la codificación de los DIP switches, ni la polaridad o el acondicionamiento eléctrico de cada señal.

## Salidas

- **LEDs de entrega:** uno por producto; se enciende el correspondiente cuando se entrega ese producto.
- **LEDs de agotado:** uno por producto; indica que su inventario llegó a cero.
- **LED de devolución:** indica la devolución de todas las monedas ingresadas al seleccionar un producto agotado; el enunciado también requiere devolver todas las monedas cuando el pago es insuficiente.
- **Cuatro displays de siete segmentos:** muestran en decimal el vuelto cuando el crédito alcanza o supera el precio.

El enunciado no especifica un actuador físico de despacho ni un mecanismo físico que devuelva monedas: describe la entrega mediante LEDs y la devolución mediante un LED indicador. Por tanto, este documento no presupone esos mecanismos.

## Ambigüedades y contradicciones

1. **Monedas admitidas frente a casos de prueba:** la interfaz descrita define `IN_COINS` como cantidad de monedas de ₡100. Sin embargo, los casos de prueba exigen pagar ₡150 como ₡100 + ₡50, pagar ₡200 como ₡100 + ₡100 y probar un pago de ₡125 como ₡100 + ₡25. La interfaz descrita no permite representar las monedas de ₡50 ni de ₡25. El enunciado no indica si debe ampliarse la interfaz de entrada o cómo codificar esas denominaciones.
2. **Insuficiencia frente a cancelación:** la sección aritmética dice que ante un faltante la máquina vuelve al inicio y devuelve todas las monedas. El caso de prueba para el producto C describe primero ₡125 y luego cancelar, con devolución de ₡125. No precisa si el pago insuficiente provoca devolución automática, si se espera una entrada de cancelación adicional o cómo se distingue una acción de otra.
3. **Bloque de display:** se requiere mostrar el vuelto en cuatro displays, pero la sección del subsistema de despliegue también dice «No conecte este bloque». No aclara si esa instrucción significa excluir la conexión física, dejar el bloque desconectado en la integración o no usarlo en la implementación.
4. **Temporizadores de 2 s:** se exige generarlos para la FSM, pero no se identifican las acciones temporizadas, sus condiciones de inicio o fin ni la cantidad de temporizadores.
5. **Nombre del subsistema de entrada:** la sección se titula «lectura del teclado mecánico hexadecimal», aunque su descripción especifica DIP switches para `PROD_SEL` e `IN_COINS` y botones `START` y `RESTART`, no un teclado hexadecimal.

Estas ambigüedades se conservan explícitamente; no se asume una resolución que el enunciado no establece.

## Referencias teóricas

- **Referencia principal:** Harris, S. L., & Harris, D. M. (2016). *Digital Design and Computer Architecture: ARM Edition*. Morgan Kaufmann.
  - Apartados de consulta: sección 3.4, *Finite State Machines*; sección 3.5, *Timing of Sequential Logic*; sección 4.6, *Finite State Machines en HDL*; sección 4.9, *Testbenches*; sección 5.2, *Arithmetic Circuits*; sección 5.4, *Sequential Building Blocks*.
- Chacón-Rodríguez, Alfonso. *Proyecto corto 3: Máquinas de estado finito en HDL*. EL-3307 Diseño Lógico, II Semestre 2026. Enunciado oficial incluido en [`Proyectos_Proyecto-Corto-3-II-Semestre-2026.pdf`](Proyectos_Proyecto-Corto-3-II-Semestre-2026.pdf).
- Chu, Pong P. *FPGA Prototyping by SystemVerilog Examples: Xilinx MicroBlaze MCS SoC Edition*. Wiley, 2018.
- Dally, William James y R. Curtis Harting. *Digital Design: A Systems Approach*. Cambridge University Press, 2012.
- Sipeed. *Tang Nano 9K*, esquemático de la tarjeta incluido en [`Tang_Nano_9k_3672_Schematic.pdf`](Tang_Nano_9k_3672_Schematic.pdf).

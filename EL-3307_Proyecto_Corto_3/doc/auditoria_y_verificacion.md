# Auditoría y verificación del Proyecto Corto 3

## Alcance y criterio

Se revisaron las fuentes SystemVerilog, bancos de prueba, documentación,
restricciones y configuración de Gowin del Proyecto Corto 3, junto con los
bloques reutilizados y sus consumidores del Proyecto Corto 2. El resumen de
hallazgos se presentó antes de modificar archivos.

Por instrucción expresa del usuario, las frases del PDF sobre escribir
comentarios en otro idioma y dejar sin conexión el despliegue se descartaron
como requisitos técnicos. El PDF original se conserva intacto como evidencia.
El requisito funcional aplicado es mostrar el vuelto decimal en cuatro dígitos.

Las dos frases aparecen en las páginas 2 y 3 del PDF, respectivamente. Su
corrección se comprobó en los archivos, no solamente en este informe. El
comentario de la FSM está en español y el registro de vuelto tiene una ruta
continua hasta `an`/`sseg`. El PDF sigue idéntico al blob de Git `0d4a230`;
su SHA-256 es `8A940E5E43F6A4536F0D9FF71C9BE919E6DD18AE917E54EE4BC1114F6F2612DE`.

## Rastros anteriores y archivos afectados

Las líneas de esta tabla corresponden al estado **anterior a la corrección**.
Los documentos versionados provenían del commit `5ae3de7`; el top y la
preparación física todavía eran archivos locales sin commit.

| Archivo | Líneas anteriores | Hallazgo y corrección |
|---|---|---|
| `src/design/vending_fsm.sv` | 128 | Único comentario en alemán encontrado; además describía como detenidas unas ramas que ya avanzaban automáticamente. Sustituido por explicación técnica en español. |
| `doc/arquitectura_general.md` | 31, 70, 111 | Trataba el idioma como obligación y el display como pendiente de conexión. Corregida la arquitectura efectiva. |
| `doc/analisis_fsm.md` | 139, 167 | Condicionaba el uso del vuelto a la instrucción descartada. El despliegue ahora es un consumidor conectado del registro de vuelto. |
| `doc/diagrama_bloques.md` | 11, 62, 65, 123–125, 144, 152 | Bloque aislado, flechas punteadas y prohibición de conexión. Diagrama actualizado con ruta real hacia los cuatro dígitos. |
| `doc/diagrama_estados_fsm.md` | 75 | Justificaba no conectar el despliegue. Actualizado al comportamiento actual. |
| `doc/diseno_subsistemas.md` | 25, 27, 35, 47, 113–114, 138 | Repetía la prohibición y dejaba BCD/multiplexación aislados. Sustituido por interfaces y reutilización reales. |
| `doc/ecuaciones_fsm.md` | 111 | Conservaba la desconexión como ambigüedad no resuelta. Ecuaciones actualizadas a la FSM real. |
| `doc/tabla_salidas_control_fsm.md` | 50 | Excluía una salida de despliegue. Actualizada la relación del vuelto con el display. |
| `doc/tabla_transiciones_fsm.md` | 63 | Asumía que el display no se conectaba. Corregido. |
| `doc/validacion_modulos_reutilizables.md` | 75 | Ordenaba mantener desconectado el mux validado. Ahora documenta su uso habilitado y compatible. |
| `src/design/vending_top.sv` | 13–15, 264, 296 | Solo exponía LED; `change_reg` carecía de consumidor. Añadidos `an`, `sseg` y la instancia del display. |
| `src/sim/tb_vending_top.sv` | 45–58, 297, 486, 490 | Comprobaba LED y vuelto por jerarquía, sin observar dígitos. Añadidas comprobaciones públicas de los cuatro dígitos y del apagado. |
| `src/build/vending_top_gowin.tcl` | 27–30 | No incorporaba BCD, ROM, mux ni generador de habilitaciones. Dependencias y recurso ROM añadidos. |
| `src/constr/vending_top.cst` y `.sdc` | 2 y 14, respectivamente | Solo cubrían 16 puertos y las salidas LED. Actualizados a 28 puertos y sus extremos visuales. |
| `doc/preparacion_tangnano9k.md` | 100–101, 129, 136–137 | Describía solo tres bloques reutilizados y aceptaba eliminar el vuelto sin salida física. Actualizada a la integración completa. |
| `work/gowin_vending_top/VALIDACION_GOWIN.md` | 22–25, 61–62, 85–86 | Evidencia histórica de la implementación sin display y de la ausencia de simulación SDF. Es un resultado generado anterior, excluido de Git. |

No se encontró otro comentario en alemán en las fuentes de los dos proyectos.
Las notas sobre desconectar las pantallas RGB/SPI tienen una causa eléctrica
distinta: sus señales comparten los GPIO elegidos. Se conservan con esa
explicación y no impiden conectar el display multiplexado externo.

## Otras discrepancias técnicas

- La FSM combinaba siguiente estado y salidas en un solo bloque. Se separó en
  tres bloques, conservando nueve estados `typedef enum` One-Hot, transiciones
  y pulsos. Los valores por defecto evitan latches.
- Las tablas preliminares describían cargas de operandos aun sin stock y una
  limpieza limitada a RESTART. Se actualizaron para reflejar la revisión de
  disponibilidad y la limpieza automática tras una devolución.
- La ROM del Proyecto 2 caracteriza 1000–1023 como `000`. No se cambió esa
  tabla ni se ocultó su limitación: el adaptador nuevo separa millares/resto y
  solo consulta direcciones 0–499. La nueva prueba cubre los 1024 valores posibles.
- Gowin rechazó inicialmente la ROM asíncrona de 1024x12 con `IF0008`: estimaba
  12 288 LUT antes de optimizar frente a 8640 disponibles. Las opciones GSC de
  memoria y una copia diagnóstica con ruta absoluta no resolvieron el error.
  La corrección final está en el adaptador: para restos de 500–999 resta 500,
  consulta la misma tabla y suma cinco a las centenas. `N=9, M=12` requiere
  profundidad 512; los datos consultados siguen siendo los originales.
- `rom_reg.sv` ahora especifica inicio y fin en `$readmemh`. Su contenido,
  lectura combinacional y puertos no cambian; con `w=10` se sigue leyendo
  0–1023. Esa delimitación no elimina por sí sola los avisos por un archivo
  demasiado largo: Questa y Gowin todavía avisan al cargar 1024 palabras en
  la instancia de profundidad 512. Los Tcl preparan exactamente el prefijo de
  512 entradas, sin modificar el original. Se compararon ambos prefijos:
  cero diferencias. La prueba dirigida de EX2412 se registra más adelante.
- `tb_keypad_decoder.sv:65` del Proyecto 2 esperaba que `*` generase `9`, aunque
  `keypad_decoder.sv:29` define `E` y el `9` ya está en fila 3/columna 3. La
  regresión completa detectó el fallo; se corrigió esa expectativa a `E` sin
  modificar el decodificador ni eliminar la prueba del `9`.
- El PDF pide monedas físicas de 100 colones, pero sus ejemplos incluyen 150
  y 125 colones y una cancelación sin entrada definida. Se mantiene el DIP de
  cantidad de monedas y se prueban A150/C125 directamente en el núcleo. El
  rechazo por insuficiencia sigue siendo automático, sin inventar CANCEL.
- El encabezado de una sección del PDF menciona teclado, mientras su contenido
  define DIP y pulsadores. La interfaz sigue la descripción funcional de 4.1.
- El PDF también contiene una regla sobre uso de herramientas en el objetivo
  3.j; no define ninguna señal, operación ni conexión del circuito.

## Integración corregida

`vending_system.change_reg` alimenta `vending_display.value`. La indicación
retenida de entrega habilita los cuatro dígitos, incluidos ceros a la izquierda:
`0050`, `0025` y `0000`. El dato y la entrega permanecen hasta RESTART. En reposo,
reset o devolución se apaga todo el display; no se muestra el faltante como si
fuera el importe devuelto.

El nuevo módulo reutiliza la ROM, el conversor BCD, el generador de pulsos y la
tabla de segmentos/multiplexación del Proyecto 2. El modo `USE_TICK` conserva
el funcionamiento antiguo por defecto. Su nuevo uso mantiene el reloj de
27 MHz y habilita el avance del selector con `tick_display`, sin clocks nuevos.

La interfaz física conserva segmentos/selectores activos altos como el top del
Proyecto 2, con parámetros para adaptar ambas polaridades. Los fuentes no
permiten identificar el modelo de display ni demostrar que existan transistores
de selección en el montaje. Esa comprobación física sigue pendiente, según la
indicación del usuario de continuar con la parte digital verificable.

## Estado de verificación

**Resultado global: INCOMPLETO.** Las corridas del 17/11/2026 aprobaron RTL,
implementación y una simulación post-ruteo con SDF. La simulación post-síntesis
no pudo ejecutarse por incompatibilidad de la netlist protegida con Questa.
La sección 4.5.3 del PDF, página 4, exige RTL y simulaciones con temporización
post-síntesis y post-colocación/ruteo para cada subsistema. No se declara
cumplida toda esa exigencia ni se presenta la versión como final validada.

Herramientas usadas: Questa FPGA Starter Edition 2025.3, instalada con
Quartus 26.1.1, y Gowin V1.9.11.03 Education, dispositivo
GW1NR-LV9QN88PC6/I5, versión C. Todos los artefactos de ejecución permanecen
en `work/`, excluido de Git. Ninguna ejecución invocó el programador.

### Regresión RTL final

Comando desde la raíz del repositorio:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File EL-3307_Proyecto_Corto_3/src/sim/run_questa.ps1
```

Resultado guardado en
`work/questa_20261117_142854_941_2e62be76/results.json`:
65 fuentes compiladas; **30 bancos aprobados, 53 190 comprobaciones, 0 errores**.
Se cotejaron los hashes de `metadata.json` contra los archivos finales: las
65 fuentes y la ROM coinciden. También coinciden las 25 entradas del manifiesto
de la implementación de netlists; las ediciones posteriores son documentación
y el controlador de ejecución, no la lógica probada.
Las cifras cuentan comprobaciones ejecutadas; no representan un porcentaje
de cobertura formal. El flujo exige resumen de cero errores y rechaza errores
de compilación, simulación, licencia o timeout.

| Proyecto | Testbench | Comprobaciones |
|---|---|---:|
| 3 | `tb_arithmetic_path` | 62 |
| 3 | `tb_change_register` | 17 |
| 3 | `tb_inventory_register` | 11 |
| 3 | `tb_price_selector` | 4 |
| 3 | `tb_product_selection_register` | 18 |
| 3 | `tb_purchase_decision` | 18 |
| 3 | `tb_request_credit_register` | 16 |
| 3 | `tb_timer_2s` | 27 |
| 3 | `tb_transaction_integration` | 52 |
| 3 | `tb_transaction_operands` | 11 |
| 3 | `tb_vending_display` | 50 476 |
| 3 | `tb_vending_fsm` | 285 |
| 3 | `tb_vending_system` | 516 |
| 3 | `tb_vending_top` | 710 |
| 2 | `tb_bcd_converter` | 12 |
| 2 | `tb_calculator_core` | 41 |
| 2 | `tb_calculator_display` | 57 |
| 2 | `tb_calculator_fsm` | 141 |
| 2 | `tb_calculator_system` | 149 |
| 2 | `tb_debouncer` | 72 |
| 2 | `tb_disp_hex_mux` | 143 |
| 2 | `tb_keypad_decoder` | 18 |
| 2 | `tb_keypad_event` | 86 |
| 2 | `tb_keypad_frontend` | 40 |
| 2 | `tb_keypad_scanner` | 25 |
| 2 | `tb_operand_register` | 41 |
| 2 | `tb_subtractor` | 17 |
| 2 | `tb_synchronizer` | 18 |
| 2 | `tb_tick_generator` | 42 |
| 2 | `tb_top` | 65 |
| **Total** | **30 bancos** | **53 190** |

PC2 suma 16 bancos y 967 comprobaciones; PC3, 14 bancos y 52 223.
Se compiló también el resto de módulos de diagnóstico de PC2. En el mux,
`USE_TICK=0` conserva exactamente la actualización anterior en cada flanco;
sus consumidores originales fijan `tick=1`. La delimitación de la ROM conserva
las direcciones originales. La corrección de la expectativa `*` del decoder
ya se explicó arriba. Los 16 bancos de PC2 pasaron con esos cambios.

El banco histórico `tb_top_post_route` de PC2 no forma parte de la regresión
RTL: requiere la netlist y `proyecto_post_route.sdf` de ese proyecto. No se
ejecutó ni se declara aprobado contra RTL. `tb_vending_netlist` se ejecuta
separadamente contra puertas, no contra fuentes RTL.

Las pruebas nuevas cubren los 1024 valores del adaptador, ambas polaridades,
cuatro posiciones y puntos decimales, blanco y retención; A200/0050, B300/0025,
C400/0000, C300 con devolución completa, agotamiento, captura estable de DIP,
rebotes, botones sostenidos, pulsos únicos y reset/RESTART. El núcleo también
pasó A150 exacto y C125 insuficiente, conservando el inventario y devolviendo
el crédito completo. La prueba del temporizador incluye intervalos reducidos,
incluido un ciclo; el STA comprueba la implementación con los contadores reales.

### Síntesis, colocación, ruteo y temporización del hardware

```powershell
& 'C:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe' 'EL-3307_Proyecto_Corto_3/src/build/vending_top_gowin.tcl'
```

Corrida final: 17/11/2026, 14:36:02, hora local. Top `vending_top` con
`DEBOUNCE_N=21`, `REFUND_CYCLES=54000000`, `DISPLAY_DIV=6750` y polaridades
activas altas para el display. El GPRJ contiene 23 archivos habilitados y
distintos: 21 SystemVerilog de diseño y dos restricciones. No incluye testbenches.

| Comprobación | Resultado real |
|---|---|
| Sintaxis, elaboración e inferencia | Síntesis completada, 0 errores |
| Colocación y ruteo | Completados |
| Reloj analizado | Único `clk_27mhz`, período 37,037037 ns |
| Fmax post-ruteo | **53,526 MHz** |
| Peor margen de setup | **+18,354 ns** |
| Peor margen de hold | **+0,561 ns** |
| Endpoints con violación de setup / hold | **0 / 0** |
| TNS de setup / hold | **0 / 0 ns** |
| Caminos / endpoints analizados | 1106 / 1107 |
| Lógica | 717/8640: 461 LUT y 256 ALU |
| Registros | 396: 389 lógicos y 7 de E/S |
| Latches | **0** |
| Puertos | **28**: 9 entradas y 19 salidas |

Se conserva una advertencia `NL0002`: Gowin elimina la frontera del módulo
combinacional `purchase_decision` al optimizar su lógica en el consumidor.
No elimina las decisiones de compra: las señales de autorización siguen en
la lógica de entrega; los casos de insuficiencia y agotamiento también pasaron
contra la netlist ruteada. No se alteró ese módulo para ocultar la advertencia.
La corrida final no tiene advertencias de anchura ni de inicialización ROM.

La guarda de antirrebote es de aproximadamente 38,836 ms; devolución,
54 millones de ciclos = 2 s; ranura de display, 6750 ciclos = 250 us;
trama completa, 1 ms. Los contadores caben en los anchos declarados y el STA
incluye sus sumas y comparadores. `tick_display` es una habilitación, no un
reloj. El uso de un recurso global para distribuir reset tampoco crea un reloj.

Las excepciones SDC terminan en entradas mecánicas o salidas visuales sin
receptor síncrono externo. No cortan el trayecto entre las etapas de los
sincronizadores ni los caminos desde el reset sincronizado hacia el núcleo.
No hay excepciones multiciclo para ocultar caminos lentos.

Evidencia local:

- `work/gowin_display_20261117.log`.
- `work/gowin_vending_top/vending_top/vending_top.gprj`.
- `work/gowin_vending_top/vending_top/impl/gwsynthesis/vending_top.log`.
- `work/gowin_vending_top/vending_top/impl/pnr/vending_top.rpt.txt`.
- `work/gowin_vending_top/vending_top/impl/pnr/vending_top.tr`.

### Simulaciones de netlists

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File EL-3307_Proyecto_Corto_3/src/sim/run_questa_netlist.ps1
```

Artefactos finales en `work/netlist_20261117_143743_365_c17aed37/`.
`results.json` informa **PARTIAL** y el proceso devuelve salida distinta de
cero. `design_inputs.json` conserva los hashes de las fuentes, restricciones,
tabla original y Tcl usados. `-SkipBuild -BuildDirectory <directorio>` verifica
esos hashes antes de reutilizar una implementación.

El envoltorio de prueba se genera exclusivamente en `work`; instancia el
mismo `vending_top` con `DEBOUNCE_N=4`, `REFUND_CYCLES=256`, `DISPLAY_DIV=3`.
Su Tcl sintetiza y rutea de nuevo esa variante a 27 MHz. El PDF permite reducir
divisores para simular temporizadores, página 4, sección 4.5.3. Los parámetros de
producción permanecen intactos y tienen su propio STA; no se atribuye a ellos
la netlist de contadores reducidos.

| Fase | Estado | Comprobaciones y evidencia |
|---|---|---|
| Post-síntesis `.vg` + `prim_sim.v` | **NO DISPONIBLE / NO APROBADA** | La compilación falla antes de ejecutar el banco: 5 errores de sintaxis/pragmas en la envoltura protegida GOWIN 2.3; ver `post_synthesis/compile.log`. |
| Post-ruteo `.vo` + `prim_tsim.v` + SDF máximo | **APROBADA para los escenarios ejecutados** | **505 comprobaciones, 0 errores**; ver `post_route_sdf/transcript.log` y `results.json`. |

La netlist post-síntesis contiene `key_keyowner="GOWIN"`. También se probó
la opción normal de salida de GowinSynthesis para generar `.v`: conservó la
misma envoltura protegida. No hay una exportación SystemVerilog compatible
comprobada en esta instalación. No se modificaron las directivas de protección
ni se sustituyó la fase por RTL o por una netlist post-ruteo sin retardos.
El bloqueo requiere una exportación o herramienta oficialmente compatible;
no es evidencia de un fallo funcional de la FSM, pero impide cerrar esa fase.

El registro de compilación conserva los siguientes cinco errores, todos en
`gowin/vending_verify_top/impl/gwsynthesis/vending_verify_top.vg`:

| Línea | Mensaje de Questa | Interpretación |
|---:|---|---|
| 30 | `unexpected "STRING_LITERAL", expecting "INTEGER NUMBER"` | Rechazo del valor de versión de la envoltura GOWIN 2.3. |
| 33 | `encrypt_agent cannot be used in an encryption envelope` | Metadato de protección no aceptado. |
| 34 | `encrypt_agent_info cannot be used in an encryption envelope` | Segundo metadato de protección no aceptado. |
| 39 | `syntax error, unexpected '+'` | La carga cifrada termina interpretándose como texto HDL. |
| 39 | `Syntax error found in the scope ... Is there a missing '::'?` | Error derivado de interpretar ese mismo contenido como identificador HDL. |

`prim_sim.v` compiló sin esos errores. Los ensayos posteriores de exportación
no produjeron una netlist funcional compatible comprobada. `-ot` generó una
plantilla de instanciación, que no equivale a un modelo funcional. Los intentos
con la interfaz de exportación tampoco aportaron una prueba aprobada del top.
Permanecen como diagnóstico local excluido de Git. El cierre documental no
reanuda Gowin, Pack User Design ni esos intentos automáticos.

La simulación post-ruteo utiliza los modelos temporales oficiales de Gowin,
`gw1n/prim_tsim.v`, precisión de 1 ps y `-sdfmax /tb_vending_netlist/uut=...`.
Questa confirma `SDF Backannotation Successfully Completed` y estos conteos:

| Objeto anotado | Cantidad |
|---|---:|
| Retardos de camino / IOPATH leídos | 2882 / 2882 |
| Comprobaciones temporales | 1434 |
| Interconexiones / INTERCONNECT leídos | 3177 / 3177 |

El banco observa únicamente los 28 puertos públicos, sin forzar contadores ni
registros internos. Comprueba A200, B300, C400, C300 insuficiente, agotamiento
de A y C, retención del vuelto, RESTART y reposición por reset. Se observaron
ocho entregas y dos devoluciones; cada devolución duró 256 ciclos.

No se suprimieron violaciones temporales ni errores de anotación. Hay una
advertencia de Questa `vopt-10908` por usar `+acc`, no de temporización.
`-sdfreport=...` genera un informe de objetos **sin** anotar; no demuestra por
sí solo que haya retardos aplicados. El script exige el resumen positivo de
anotación y coteja los conteos de IOPATH e interconexiones.

El informe también registra 8550 instancias con objetos specify sin anotar
o parcialmente anotados en la biblioteca, incluidos mux internos y controles
PERIOD/WIDTH no exportados en el SDF. Los retardos y controles suministrados
por el SDF sí se anotaron, pero no se afirma que todos los controles posibles
de la biblioteca estén cubiertos. Esta simulación de integración no constituye
una colección post-síntesis/post-ruteo de bancos individuales de cada subsistema
ni una prueba eléctrica de la placa.

En total hay **31 bancos/fases aprobados y 53 695 comprobaciones ejecutadas
sin errores en esas fases**: 30 RTL y un banco post-ruteo. La fase post-síntesis
queda separada y sus 5 errores de compilación no se ocultan en ese total.

### Prueba dirigida de EX2412 y compra A con siete monedas

Se ejecutó una prueba adicional en Questa con el diseño actual, sin modificar
módulos originales ni ejecutar Gowin o Pack User Design. El caso completo
parte de reset, selecciona A, introduce siete monedas de 100 y pulsa START.
Se observaron las salidas públicas `an` y `sseg` para confirmar las cuatro
cifras de `0550`, los puntos apagados y el único dígito habilitado por ranura.

La advertencia histórica de Gowin era:

```text
WARN (EX2412): Illegal entry at ../design/bcdtable.txt:513 for index 512 in range [0:511]
```

La tabla original tiene 1024 entradas, pero la instancia de PC3 usa una ROM
de 512 posiciones. El aviso identifica la primera palabra que excede esa
profundidad: dirección 512, línea 513. No indica que el BCD almacenado en esa
línea tenga caracteres inválidos. El último registro de implementación
`work/gowin_display_20261117.log` no contiene EX2412: el Tcl ya prepara un
archivo de exactamente 512 entradas. Ese prefijo coincide con el original
en las 512 posiciones, sin diferencias.

Para A700 se comprobó esta ruta interna en RTL:

```text
credito = 700; precio = 150; vuelto = 550
rom_value = 550 - 500 = 50
rom_address = 50; ROM[50] = 12'h050
centenas = 0 + 5 = 5; decenas = 5; unidades = 0; millares = 0
display = 0550
```

Por tanto, el vuelto 550 no se utiliza directamente como dirección de la ROM.
La normalización del adaptador mantiene sus consultas en 0–499, dentro de
0–511. Las cifras observadas en las salidas fueron:

| Posición | `an` | `sseg` activo alto | Dígito |
|---|---|---|---:|
| Millares | `1000` | `7e` | 0 |
| Centenas | `0100` | `5b` | 5 |
| Decenas | `0010` | `5b` | 5 |
| Unidades | `0001` | `7e` | 0 |

| Configuración ejecutada | Comprobaciones | Errores | Resultado |
|---|---:|---:|---|
| RTL con tabla original de 1024 entradas | 46 | 0 | `0550` |
| RTL con la copia de Gowin de 512 entradas | 46 | 0 | `0550` |
| Netlist post-ruteo existente, SDF máximo anotado | 34 | 0 | `0550` |
| **Total dirigido** | **126** | **0** | **APROBADO para estos escenarios** |

También se mantuvo `0550` al cambiar los DIP durante la transacción y al
mantener START presionado. En RTL se comprobó que A bajó de tres a dos unidades
una sola vez; RESTART apagó el display sin reponer inventario.

Limitaciones y avisos reales:

- Con las 1024 entradas, Questa conserva el aviso equivalente
  `vsim-PLI-3407: Too many data words read on line 513 ... address range [0:511]`,
  incluso con los límites explícitos de `$readmemh`. La prueba pasó y no se
  suprimió ese aviso. Con el archivo de 512 entradas desaparece el aviso ROM.
- Las tres ejecuciones conservan el aviso `vopt-10908` por `+acc`; no es una
  violación temporal. Cero errores no significa cero advertencias.
- En RTL se redujo el antirrebote a N=4 y el temporizador a 256 ciclos; el
  barrido mantuvo `DISPLAY_DIV=6750`. La netlist existente usa N=4,
  `REFUND_CYCLES=256` y `DISPLAY_DIV=3`, a 27 MHz. No se sintetizó otra versión.
- La anotación SDF confirmó 2882 retardos de camino, 1434 comprobaciones
  temporales y 3177 interconexiones. Conserva las limitaciones de biblioteca
  descritas en la sección anterior; no demuestra una prueba física de la placa.
- Este resultado no aprueba la simulación post-síntesis ni convierte el aviso
  en inocuo para otras memorias o configuraciones. Se verificaron esta ruta,
  las tablas usadas y el caso A700 solicitado.

Artefactos locales: `work/ex2412_a700/tb_vending_a700.sv`,
`work/ex2412_a700/run_probe.ps1` y
`work/ex2412_a700/run_20261117_225520/results.json`, con los tres transcripts.
Son pruebas y resultados locales excluidos del commit junto con el resto
de `work/`. El caso se registra documentalmente; no cambia el número de
30 bancos de la regresión versionada. Sus 126 comprobaciones son adicionales
a las 53 695 de las corridas base, no un porcentaje de cobertura.

Se cotejaron los hashes de las 65 fuentes de la regresión RTL y los de los
insumos de esta prueba dirigida con los archivos actuales: cero cambios.
No fue necesario repetir síntesis o regresiones por este cierre documental.

### Pines y montaje

Se cotejaron los 28 `IO_LOC` del CST con las 28 filas colocadas por Gowin:
todos distintos y todos con restricción aplicada. Se verificaron IO_TYPE y
BankVccio: ocho señales en banco 3, 1,8 V; las otras veinte a 3,3 V.
La tabla completa de puertos, pines de encapsulado y contactos J5/J6 está en
[preparación de la Tang Nano 9K](preparacion_tangnano9k.md).

- Reloj 52; S1/reset 4; S2/RESTART 3; START 30.
- Producto 25/26; monedas 27/28/29.
- Entrega 10/11/13; agotado 14/15/16; devolución 33.
- Dígitos, de unidades a millares: 34/40/35/41.
- Segmentos a–g: 42/51/48/49/76/77/31; DP: 32.

Los LED integrados son activos bajos; devolución externa activa alta; segmentos
y selectores del display activos altos por defecto, igual que PC2. GPIO 31/32
son E/S ordinarias IOB15A/B; se evitan los pines de configuración 53–57 y los
de flash, UART, SD, HDMI y JTAG. El uso de GPIO compartidos presupone que las
pantallas RGB y SPI permanezcan desconectadas. No se certifica ausencia de
conflictos si se conectan esos periféricos simultáneamente.

El modelo de display, sus resistencias y transistores reales no están
documentados en el repositorio. Falta revisar ese montaje antes de conectar
o programar la tarjeta; la polaridad digital no basta para identificar el
tipo de display ni su capacidad de corriente.

### Revisión de Git y archivos afectados

Se revisaron `git status`, `git diff`, archivos nuevos y `git diff --check`.
El PDF, `bcdtable.txt`, `vending_system.sv`, inventarios, precios, aritmética,
sincronizador y debouncer originales permanecen sin cambios. Los resultados
generados, proyectos GPRJ, bibliotecas, bitstreams y logs no se incluyen en Git.

Hay 37 archivos locales afectados: nueve en PC2 y veintiocho en PC3.

La revisión específica de PC2 confirmó el alcance siguiente:

- `disp_hex_mux.sv`: parámetro opcional `USE_TICK`, desactivado por defecto,
  y entrada `tick`; el comportamiento original sigue avanzando en cada ciclo.
- `calculator_display.sv`, `calculator_input_diag_top.sv`, `keypad_diag_top.sv`,
  `keypad_frontend_diag_top.sv`, `operand_register_diag_top.sv` y
  `tb_disp_hex_mux.sv`: únicamente conectan la nueva entrada a `1'b1`.
- `rom_reg.sv`: límites explícitos de lectura, sin alterar tabla, puertos,
  latencia combinacional ni datos de las instancias originales. El aviso de
  archivo largo y su alcance están documentados arriba.
- `tb_keypad_decoder.sv`: corrige una expectativa preexistente de `*` a `E`,
  conforme al decodificador ya existente. No cambia el teclado ni su lógica;
  la prueba independiente de la tecla `9` permanece.

Los nueve cambios tienen relación con la reutilización o con la integridad de
la regresión utilizada para revisarla. Los 16 bancos RTL de PC2 pasaron con
967 comprobaciones. No se incluyeron cambios adicionales a su funcionamiento.

| Proyecto | Archivos |
|---|---|
| 2, diseño | `src/design/calculator_display.sv`, `calculator_input_diag_top.sv`, `disp_hex_mux.sv`, `keypad_diag_top.sv`, `keypad_frontend_diag_top.sv`, `operand_register_diag_top.sv`, `rom_reg.sv` |
| 2, pruebas | `src/sim/tb_disp_hex_mux.sv`, `tb_keypad_decoder.sv` |
| 3, raíz | `.gitignore`, `README.md` |
| 3, documentación | `doc/analisis_fsm.md`, `arquitectura_general.md`, `auditoria_y_verificacion.md`, `diagrama_bloques.md`, `diagrama_estados_fsm.md`, `diseno_subsistemas.md`, `ecuaciones_fsm.md`, `preparacion_tangnano9k.md`, `tabla_salidas_control_fsm.md`, `tabla_transiciones_fsm.md`, `validacion_modulos_reutilizables.md` |
| 3, construcción | `src/build/Makefile`, `vending_top_gowin.tcl`, `verify_netlist_gowin.tcl` |
| 3, restricciones | `src/constr/vending_top.cst`, `vending_top.sdc` |
| 3, diseño | `src/design/vending_fsm.sv`, `vending_display.sv`, `vending_top.sv` |
| 3, pruebas | `src/sim/run_questa.ps1`, `run_questa_netlist.ps1`, `tb_vending_display.sv`, `tb_vending_fsm.sv`, `tb_vending_netlist.sv`, `tb_vending_system.sv`, `tb_vending_top.sv` |

Los intentos anteriores se detuvieron sin commit ni push mientras se buscaba
cerrar la verificación completa. La instrucción posterior del usuario autoriza
un **commit de avance** con la simulación post-síntesis expresamente bloqueada.
El mensaje autorizado para este cierre es:
`fix: integrar display y corregir FSM`.

Este avance conserva las pruebas aprobadas y registra las pendientes. No
equivale a una versión final validada. Los archivos de `work/`, cachés,
bibliotecas, netlists, registros y bitstreams generados se excluyen de la
selección de archivos. Antes de publicar se comprueba la referencia remota;
el push a `main` se realiza sin `--force`. El identificador resultante y los
archivos incluidos se consultan con `git log -1` y `git show --stat HEAD`.

Referencias de herramientas: Gowin SUG100-4.4.2E, sección 7, páginas 83–84
(`.vg`/`prim_sim.v` y `.vo`/SDF/`prim_tsim.v`); SUG550-2.0.1E, sección 5.16;
manual local Questa SIM Reference, opciones `-sdfreport=<filename>` y
`+sdf_verbose`. Referencias eléctricas oficiales enlazadas en la guía de montaje.

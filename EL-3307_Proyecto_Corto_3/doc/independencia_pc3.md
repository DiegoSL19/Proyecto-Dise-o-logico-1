# Independencia del Proyecto Corto 3

Verificación del 18/11/2026, sobre la base `e1ca2ac`. El PC3 compila y se
sintetiza sin necesitar la carpeta del Proyecto Corto 2. Se comprobó con una
copia aislada del PC3, sin carpeta hermana PC2, y después se regeneró el
proyecto Gowin de la carpeta de trabajo.

## Copias conservadas

Se copiaron los siguientes archivos de `EL-3307_Proyecto_Corto_2/src/design`
a `src/design/reused`, sin editar su lógica, interfaces ni valores por defecto.
Los ocho archivos coinciden byte por byte con sus fuentes y producen los
mismos blobs de Git que las versiones del commit base.

| Archivo | SHA-256 de la copia verificada |
|---|---|
| `synchronizer.sv` | `9CB8C94C4A65DA928EC6A7DF318410EE0EF3037B3FBA6C1BCDC7DF4E49D43F8D` |
| `debouncer.sv` | `77E06067AE375F879E15F759CECC7CC10E1BAFF5F93DE28DD2417A61753736A8` |
| `subtractor.sv` | `8449C6D5D8ACE554D5DCF363180F9B0CF56408377118E056FD65C4FE13B1FFED` |
| `bcd_converter.sv` | `053CC0543F113E8C327375CCEAD6F4FBEA22AD44BD8D75294F38FEEBA2C7A83A` |
| `rom_reg.sv` | `083EBDE77A8FFC6DF7807E2036B26A33784833A5CB368BD9FB557693FB553172` |
| `tick_generator.sv` | `8F7F4C65D5D0AADBD675E008E7E6C4B0191FF58AB4E4A5C1AA6C0C1DCE8D7C79` |
| `disp_hex_mux.sv` | `9BB0EC5CCE082E72C3367C047D23F740A4B98BB89B480EA44BD8C3B65D3312DE` |
| `bcdtable.txt` | `AA348F806E7013D2E1AD34DBE669EF35712C4EC20EFF4229835D143104675D8C` |

Los 14 archivos de diseño que ya existían directamente en `src/design`,
incluidos `vending_top`, `vending_system`, `vending_fsm` y `vending_display`,
permanecen idénticos al commit base. También permanecen intactos el PC2
completo, los precios, inventarios y las restricciones CST/SDC. Se conservan
la FSM de nueve estados One-Hot, devolución automática, LED, captura de
entradas, antirrebote y registro del vuelto.

## Rutas y compilación

| Archivo | Cambio de dependencia |
|---|---|
| `src/build/vending_top_gowin.tcl` | Incorpora los siete SV de `src/design/reused`; prepara la ROM desde la copia local. Regenera el GPRJ para `vending_top`. |
| `src/build/verify_netlist_gowin.tcl` | Usa las mismas copias para la variante de simulación de netlists. |
| `src/build/Makefile` | Prerrequisitos locales de diseño, ROM y restricciones; no consulta carpetas hermanas. |
| `src/sim/run_questa.ps1` | Compila diseño, módulos reutilizados y bancos del PC3. Prepara la ROM local y registra hashes. |
| `src/sim/run_questa_netlist.ps1` | Registra insumos locales y ejecuta las fases de puertas con las bibliotecas del dispositivo. |

`vending_display.sv` conserva sus instancias originales. La lista de fuentes
resuelve `bcd_converter`, `rom_reg`, `tick_generator` y `disp_hex_mux` con
las copias locales. Se compilan 21 archivos de diseño, con 21 definiciones
de módulo y **cero duplicadas**. El GPRJ generado tiene 23 archivos habilitados
y únicos: esos 21 SV y las dos restricciones, sin testbenches ni rutas PC2.
El Tcl es la configuración reproducible; el GPRJ generado queda en `work/`.

La tabla fuente conserva sus 1024 palabras. Los tres flujos preparan su
prefijo de 512 palabras en el directorio `design` contiguo al directorio de
ejecución, respetando la ruta original `../design/bcdtable.txt`. Las instancias
del PC3 tienen nueve bits de dirección; el adaptador solo consulta 0–499.
Para 500–999 resta 500 antes de convertir y suma cinco a las centenas.
Así, 550 consulta ROM[50] y se muestra como `0550`. No se alteró la tabla ni
se ocultó una advertencia: el archivo de ejecución tiene la profundidad
correcta. No aparecieron EX2412 ni avisos de exceso de palabras en estas corridas.

Desde la carpeta PC3, los comandos son:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File src/sim/run_questa.ps1
& 'C:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe' 'src/build/vending_top_gowin.tcl'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File src/sim/run_questa_netlist.ps1
```

También se comprobó `make -n gowin` desde `src/build`: resolvió todos los
prerrequisitos locales y produjo el comando correcto. La síntesis real se
ejecutó con el Tcl. En Windows, los flujos conservan los alias cortos 8.3
necesarios para estas instalaciones de las herramientas y las rutas con ñ.

## Pruebas ejecutadas sin PC2

Se copiaron únicamente los archivos del PC3 a
`work/standalone_20261118_f16f550c/pc3`. No se copió el PC2 ni existía una
carpeta hermana con ese nombre. Los manifiestos verifican que todas las
fuentes del usuario y la ROM pertenecen a esa copia; las bibliotecas del
fabricante proceden de la instalación de Gowin.

Questa FPGA Starter Edition 2025.3 compiló **35 fuentes**: 21 de diseño y
14 bancos RTL. Resultado: **14 bancos aprobados, 52 278 comprobaciones,
cero errores**.

| Banco RTL | Comprobaciones |
|---|---:|
| `tb_arithmetic_path` | 62 |
| `tb_change_register` | 17 |
| `tb_inventory_register` | 11 |
| `tb_price_selector` | 4 |
| `tb_product_selection_register` | 18 |
| `tb_purchase_decision` | 18 |
| `tb_request_credit_register` | 16 |
| `tb_timer_2s` | 27 |
| `tb_transaction_integration` | 52 |
| `tb_transaction_operands` | 11 |
| `tb_vending_display` | 50 476 |
| `tb_vending_fsm` | 285 |
| `tb_vending_system` | 516 |
| `tb_vending_top` | 765 |
| **Total** | **52 278** |

Se comprobaron los cuatro dígitos de `0050` (A con 200), `0025` (B con 300),
`0000` (C con 400) y `0550` (A con 700), además de devolución, agotamiento,
retención, DIP cambiantes, rebotes y pulsadores sostenidos. El caso A700
quedó añadido al banco versionado `tb_vending_top` y al banco de netlists.
El banco del display conserva su barrido de los 1024 valores y ambas
polaridades. Los hashes de las 35 fuentes probadas coinciden con los
archivos finales de trabajo.

Esta regresión ya no incorpora los bancos del PC2: no depende de su carpeta.
Las cifras anteriores de 30 bancos y 53 190 comprobaciones pertenecen a la
corrida conjunta del commit base y se conservan como historial en la auditoría.
No se volvieron a modificar ni ejecutar los bancos del PC2 en esta reorganización.

## Gowin y temporización

Gowin V1.9.11.03 Education completó síntesis, colocación, ruteo y STA tanto
en la copia aislada como en la carpeta original, con el mismo resultado:

| Comprobación | Resultado |
|---|---|
| Dispositivo | GW1NR-LV9QN88PC6/I5, revisión C |
| Top y reloj | `vending_top`, único reloj de 27 MHz |
| Parámetros reales | `DEBOUNCE_N=21`, `REFUND_CYCLES=54000000`, `DISPLAY_DIV=6750` |
| Fmax post-ruteo | **53,526 MHz** |
| Peor margen de setup / hold | **+18,354 ns / +0,561 ns** |
| Endpoints con violación de setup / hold | **0 / 0**, TNS 0 / 0 ns |
| Caminos / endpoints analizados | 1106 / 1107 |
| Lógica / registros / latches | 717 / 396 / 0 |
| Puertos físicos | 28, asignaciones CST/SDC conservadas |
| Definiciones duplicadas y errores de ROM | **0** |

Se mantiene el aviso NL0002: el optimizador elimina la frontera del módulo
combinacional `purchase_decision`. No elimina su función. Los 28 pines se
cotejaron contra el reporte: todos restringidos, sin duplicados; ocho E/S
en banco de 1,8 V y veinte de 3,3 V, igual que la implementación anterior.

## Simulaciones de netlists y límites

El flujo independiente volvió a sintetizar y rutear la variante con
`DEBOUNCE_N=4`, `REFUND_CYCLES=256` y `DISPLAY_DIV=3`. No cambia los
parámetros reales de producción; reduce el tiempo de simulación.

| Fase ejecutada | Resultado real |
|---|---|
| Post-ruteo con `prim_tsim.v` y SDF máximo | **565 comprobaciones, cero errores**; nueve entregas y dos devoluciones, incluido A700/0550. |
| Anotación SDF | Confirmada: 2882 caminos, 1434 controles temporales y 3177 interconexiones. |
| Post-síntesis `.vg` con `prim_sim.v` | **NO DISPONIBLE / NO APROBADA**: Questa rechaza la envoltura GOWIN 2.3 antes de ejecutar el banco. |

La nueva compilación post-síntesis conserva cinco errores en
`gowin/vending_verify_top/impl/gwsynthesis/vending_verify_top.vg`:

| Línea | Mensaje real y causa |
|---:|---|
| 30 | `unexpected "STRING_LITERAL", expecting "INTEGER NUMBER"`: rechaza la versión de la envoltura. |
| 33 | `encrypt_agent cannot be used in an encryption envelope`: metadato no aceptado. |
| 34 | `encrypt_agent_info cannot be used in an encryption envelope`: metadato no aceptado. |
| 39 | `syntax error, unexpected '/'`: interpreta la carga cifrada como HDL. |
| 39 | `Syntax error found in the scope following 'cWBrIR'. Is there a missing '::'?`: error derivado de esa carga cifrada. |

`prim_sim.v` compila; el fallo está en la protección del netlist, no en la
ROM o en rutas al PC2. No se eliminaron ni alteraron bloques protegidos ni se
sustituyó esta fase por RTL. El script termina con estado `PARTIAL` y código 2,
para conservar visible el bloqueo. Los cinco errores de esta fase no se
cuentan como cero errores de las fases aprobadas. No se ejecutó Pack User Design.

La simulación SDF mantiene las limitaciones de anotación de biblioteca y
alcance explicadas en la auditoría. No representa todos los bancos de
subsistemas exigidos por el PDF ni una prueba eléctrica. La verificación
completa del proyecto sigue pendiente por esos puntos y por el montaje real
del display. No se programó la FPGA.

## Evidencias locales excluidas de Git

Rutas relativas al PC3:

- `work/independent_snapshot.json`: ubicación y ausencia de carpeta hermana PC2.
- `work/standalone_20261118_f16f550c/pc3/work/questa_20261118_091314_799_abedca4a/`: resultados, fuentes y hashes de la regresión RTL.
- `work/standalone_20261118_f16f550c/pc3/work/`: `gowin_independent.log` y el directorio `gowin_vending_top/` de la implementación aislada.
- `work/standalone_20261118_f16f550c/pc3/work/netlist_20261118_092302_540_ce0a6591/`: resultados, errores post-síntesis y simulación SDF.
- `work/gowin_independent_local.log` y `work/gowin_vending_top/`: proyecto local regenerado y reportes de implementación.

Solo se versionan fuentes, pruebas, configuraciones y documentación. Los
proyectos generados, netlists, bibliotecas, cachés, registros y bitstreams
permanecen excluidos de Git.

# Preparacion de la Tang Nano 9K

El modulo superior es `vending_top`. La maquina conserva el inventario entre
compras y muestra el vuelto decimal mediante cuatro digitos multiplexados.
El flujo de Gowin prepara sintesis, colocacion, ruteo y temporizacion; no
invoca el programador de la FPGA.

## Archivos de configuracion

- `src/constr/vending_top.cst`: ubicaciones, voltajes, pull-up y capacidad de salida.
- `src/constr/vending_top.sdc`: reloj de 27 MHz y excepciones de interfaces asincronas.
- `src/build/vending_top_gowin.tcl`: proyecto nativo y ejecucion de sintesis y PnR.

La plantilla `.txt` es una referencia y no se agrega al proyecto. El `.cst` real
utiliza `IO_LOC` para ubicar pines e `IO_PORT` para sus atributos.

## Conexiones fisicas

Ver la placa por su cara de componentes, con USB-C arriba y HDMI abajo. J5 es
la hilera izquierda y J6 la derecha. Un numero de pin FPGA no equivale a una
posicion de estos conectores.

| Puerto | Pin FPGA | Ubicacion | Nivel |
|---|---:|---|---|
| `clk` | 52 | Oscilador integrado, 27 MHz | 3,3 V |
| `reset_n` | 4 | S1 integrado | 1,8 V |
| `restart_n` | 3 | S2 integrado | 1,8 V |
| `start_n` | 30 | J5.10 | 3,3 V |
| `product_sw[0]` | 25 | J5.5 | 3,3 V |
| `product_sw[1]` | 26 | J5.6 | 3,3 V |
| `coins_sw[0]` | 27 | J5.7 | 3,3 V |
| `coins_sw[1]` | 28 | J5.8 | 3,3 V |
| `coins_sw[2]` | 29 | J5.9 | 3,3 V |
| `delivery_led_n[0]` | 10 | LED1: entrega A | 1,8 V |
| `delivery_led_n[1]` | 11 | LED2: entrega B | 1,8 V |
| `delivery_led_n[2]` | 13 | LED3: entrega C | 1,8 V |
| `empty_led_n[0]` | 14 | LED4: agotado A | 1,8 V |
| `empty_led_n[1]` | 15 | LED5: agotado B | 1,8 V |
| `empty_led_n[2]` | 16 | LED6: agotado C | 1,8 V |
| `refund_led` | 33 | J5.11: devolucion externa | 3,3 V |
| `an[0]` | 34 | J5.12: unidades | 3,3 V |
| `an[1]` | 40 | J5.13: decenas | 3,3 V |
| `an[2]` | 35 | J5.14: centenas | 3,3 V |
| `an[3]` | 41 | J5.15: millares | 3,3 V |
| `sseg[6]` | 42 | J5.16: segmento a | 3,3 V |
| `sseg[5]` | 51 | J5.17: segmento b | 3,3 V |
| `sseg[4]` | 48 | J6.19: segmento c | 3,3 V |
| `sseg[3]` | 49 | J6.20: segmento d | 3,3 V |
| `sseg[2]` | 76 | J6.11: segmento e | 3,3 V |
| `sseg[1]` | 77 | J6.10: segmento f | 3,3 V |
| `sseg[0]` | 31 | J6.21: segmento g | 3,3 V |
| `sseg[7]` | 32 | J6.22: punto decimal | 3,3 V |

Hay 28 pines distintos: nueve entradas y diecinueve salidas. GPIO 25 a 30 no
comparten los perifericos integrados usados en este montaje. Los pines del
display externo se comparten con los conectores RGB o SPI: ambas pantallas
deben permanecer desconectadas. GPIO 31 y 32 son IOB15A e IOB15B del banco 2;
el nombre RGB_INIT identifica su uso en el conector, no una funcion de
configuracion de la FPGA. Se evitan los pines 53 a 57, flash, UART, SD, HDMI
y JTAG, sin cambiar la configuracion de esos perifericos.

Las referencias S1 y S2 siguen los componentes del esquema 3672, revision 6202.
Algunos nombres de red conservan S1/S2 intercambiados. Comprobar la revision y
la serigrafia de la unidad antes del montaje.

## Protoboard

1. Llevar J6.23 (GND) a la tierra de la protoboard y J6.24 (3V3) a su alimentacion.
2. Conectar cada uno de los cinco contactos DIP entre su entrada de J5 y GND.
   El CST habilita pull-up interno. Se recomiendan resistencias externas de
   10 kohm desde las entradas a 3V3 para mantener niveles definidos con cables.
3. Conectar START como pulsador normalmente abierto entre J5.10 y GND,
   igualmente con pull-up de 10 kohm a 3V3 recomendado.
4. Conectar J5.11 a una resistencia de 1 kohm, luego al anodo de un LED rojo;
   conectar su catodo a GND. Este LED se enciende con un uno logico.
5. RESET, RESTART y los otros seis LED ya estan montados en la tarjeta.
   Los seis LED integrados se encienden con un cero logico.
6. Para un display de cuatro digitos sin controlador integrado, disponer una
   resistencia por segmento y una etapa de seleccion por cada digito. El
   transistor de seleccion conduce la suma de corrientes de los segmentos;
   esa corriente comun no debe circular por un GPIO. Dimensionar resistencias
   de segmento y de control segun la hoja de datos del display y del transistor.

J6.18 entrega 5 V y no se utiliza en este montaje. No aplicar 3,3 V a los pines
del banco de 1,8 V. La seleccion `IO_TYPE` no cambia la alimentacion fisica de
un banco. Si faltan las cabeceras de 2,54 mm, deben soldarse antes de conectar
los cables.

El RTL invierte los DIP: contacto abierto significa bit logico cero y cerrado
significa uno. Producto A es `00`, B es `01`, C es `10`; `11` se rechaza.
Las monedas se cuentan en binario, con pesos de una, dos y cuatro monedas de
100 colones para los bits 0, 1 y 2.

## Interfaz del display

`vending_display` reutiliza `bcd_converter`, `rom_reg`, `disp_hex_mux` y
`tick_generator` del Proyecto Corto 2. El valor mostrado es `change_reg`;
permanece visible despues de entregar el producto y hasta RESTART. Se
muestran cuatro cifras decimales con ceros a la izquierda: A pagado con 200
colones muestra `0050`, B con 300 muestra `0025` y C con 400 muestra `0000`.
El punto decimal permanece apagado. En reset, reposo y devolucion se apagan
los cuatro digitos.

La configuracion inicial usa `SEGMENTS_ACTIVE_LOW=0` y `DIGITS_ACTIVE_LOW=0`,
las mismas polaridades fisicas que el modulo superior del Proyecto Corto 2:
un uno enciende el segmento o habilita su etapa de seleccion. Esta interfaz
es compatible con un display de catodo comun y etapas NPN/NMOS por el lado
de tierra. La polaridad del conector no demuestra que ese sea el hardware
disponible: falta confirmar el modelo, su pinout y las etapas de potencia.
Los parametros permiten adaptar la interfaz digital cuando se identifique
el montaje; tambien deben revisarse entonces el cableado y los pull-down.

Los nuevos GPIO son LVCMOS33 con DRIVE=4 y pull-down. Esta capacidad de
salida no sustituye las resistencias limitadoras. No conectar a los GPIO
salidas de modulos de 5 V. Si se usa otro tipo de display o un controlador
integrado, verificar primero su tension y la polaridad de sus entradas.

## Temporizacion

Los parametros de hardware son `DEBOUNCE_N=21`, `REFUND_CYCLES=54000000` y
`DISPLAY_DIV=6750`.
No se agregan los bancos de prueba ni sus parametros reducidos al proyecto.

| Elemento | Ciclos | Duracion a 27 MHz |
|---|---:|---:|
| Ventana de antirrebote | 1048576 | Aproximadamente 38,836 ms |
| Guarda de estabilidad | 1048584 | Aproximadamente 38,836 ms |
| Indicacion de devolucion | 54000000 | 2 s |
| Seleccion de un digito | 6750 | 250 us |
| Trama de cuatro digitos | 27000 | 1 ms, 1000 tramas/s |

Los contadores de antirrebote usan 21 bits, las guardas 32 bits y el temporizador
26 bits. Sus sumas y comparaciones deben cumplir el periodo de 37,037037 ns en
cada ciclo; no se usan relojes derivados ni excepciones multiciclo.

El SDC excluye las llegadas de los contactos asincronos y de S1 crudo. Las
rutas entre etapas de sincronizacion y las rutas internas desde el reset
sincronizado permanecen bajo analisis. Los extremos fisicos de los LED y del
display se excluyen porque no tienen un receptor sincronizado externo; las
rutas entre registros, las habilitaciones y el reset interno permanecen
temporizados. El refresco usa pulsos de habilitacion de un ciclo: todos los
registros conservan el mismo reloj de 27 MHz y no hay reloj derivado del tick.

## Ejecucion de Gowin

Desde la raiz del repositorio, en PowerShell:

```powershell
& 'C:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe' 'EL-3307_Proyecto_Corto_3/src/build/vending_top_gowin.tcl'
```

El Tcl agrega los archivos SystemVerilog de `src/design` y siete copias locales
en `src/design/reused`: `synchronizer.sv`, `debouncer.sv`, `subtractor.sv`,
`tick_generator.sv`, `rom_reg.sv`, `bcd_converter.sv` y `disp_hex_mux.sv`.
Los testbenches no forman parte del proyecto de sintesis.
Selecciona `GW1NR-LV9QN88PC6/I5`, version C, y `vending_top` como modulo superior.
No invoca el programador. El Makefile de `src/build` ofrece objetivos para
este flujo nativo y para la regresion RTL; no tiene objetivos de programacion.

Gowin rechaza caracteres no ASCII en el directorio del proyecto. El Tcl utiliza
los alias cortos 8.3 existentes de Windows, que apuntan a los mismos archivos.
La consola agrega los `.sv` como tipo `verilog`, con el lenguaje seleccionado
explicitamente como SystemVerilog 2017. La frecuencia de GowinSynthesis se fija
mediante `global_freq 27` y el SDC define el periodo usado en el analisis final.

El conversor BCD conserva la ruta relativa original `../design/bcdtable.txt`.
Antes de crear el proyecto, el Tcl lee `src/design/reused/bcdtable.txt` y
prepara sus primeras 512 entradas en
`work/gowin_vending_top/design/bcdtable.txt`, junto al directorio de ejecucion
`work/gowin_vending_top/vending_top`. Este prefijo coincide dato por dato con
el original. El adaptador consulta 0 a 499, resta 500 para el tramo superior y
suma cinco a las centenas. La profundidad 512 evita el limite de inferencia
de la ROM de 1024x12 en Gowin. La tabla es un dato de inicializacion, no una
fuente HDL; el original de 1024 entradas no se modifica.

El archivo GPRJ generado puede guardar rutas absolutas con alias 8.3. El Tcl
es la entrada reproducible del flujo y regenera el proyecto con los archivos
de la copia actual del repositorio. No se necesitan archivos de usuario de
la GUI, caches ni resultados generados para regenerarlo.

## Estado de verificacion

Corrida aislada del 18/11/2026 sin carpeta PC2: 14 bancos RTL aprobados,
52 278 comprobaciones y cero errores. Gowin V1.9.11.03 Education completo
sintesis, colocacion, ruteo y STA de `vending_top` con los parametros reales.
Fmax: 53,526 MHz; peor margen de setup: +18,354 ns; hold: +0,561 ns.
No hubo violaciones de setup ni hold. Se usaron 717 unidades logicas,
396 registros, cero latches y los 28 puertos quedaron asignados.

La variante con divisores reducidos paso 565 comprobaciones post-ruteo con
SDF real, pero la simulacion post-sintesis no pudo ejecutarse: Questa rechaza
la proteccion GOWIN del `.vg`. El estado global es **incompleto**, no una
version final validada. Consultar [la independencia del PC3](independencia_pc3.md)
y [la auditoria](auditoria_y_verificacion.md) para los artefactos, comandos,
cobertura y limitaciones de cada fase.

Archivos para abrir o revisar:

- [Proyecto nativo de Gowin](../work/gowin_vending_top/vending_top/vending_top.gprj).
- [Reporte de PnR y pines](../work/gowin_vending_top/vending_top/impl/pnr/vending_top.rpt.txt).
- [Reporte de temporizacion](../work/gowin_vending_top/vending_top/impl/pnr/vending_top.tr).
- [Registro de sintesis](../work/gowin_vending_top/vending_top/impl/gwsynthesis/vending_top.log).

El flujo puede generar un bitstream local en `impl/pnr/vending_top.fs`.
La verificacion fisica en protoboard sigue pendiente: falta identificar el
display y sus etapas, revisar el montaje y comprobarlo en la placa. El Tcl
no carga el bitstream ni ejecuta el programador.

## Fuentes

- [Pinmap oficial de Sipeed](https://wiki.sipeed.com/hardware/zh/tang/Tang-Nano-9K/assets/clip_image010.webp).
- [Esquema oficial Tang Nano 9K 3672](https://dl.sipeed.com/fileList/TANG/Nano%209K/2_Schematic/Tang_Nano_9k_3672_Schematic.pdf).
- [Documentacion de la placa](https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html).
- [Gowin Design Timing Constraints User Guide](https://cdn.gowinsemi.com.cn/SUG940E.pdf), tambien instalado como SUG940-2.0E.

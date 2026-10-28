# Proyecto corto 2: Diseño digital sincrónico en HDL

Implementación para **EL-3307 Diseño Lógico** sobre una **Tang Nano 9K**. El sistema captura dos operandos decimales desde un teclado hexadecimal 4×4, ejecuta una resta mediante complemento a la base y despliega operandos/resultado con signo en cuatro displays de 7 segmentos multiplexados.

## 1. Abreviaturas y definiciones
- **FPGA**: Field Programmable Gate Array.
- **FSM**: Finite State Machine.
- **BCD**: Binary Coded Decimal.
- **RTL**: Register Transfer Level.
- **P&R**: Place and Route.
- **RCO**: Ripple Carry Output.

## 2. Referencias
- Pong P. Chu, *FPGA Prototyping by SystemVerilog Examples*, Wiley, 2018.
- Documentación del curso EL-3307 y referencias indicadas en el instructivo del Proyecto corto 2.
- Esquemático de la Tang Nano 9K incluido en `doc/Tang_Nano_9k_3672_Schematic.pdf`.

## 3. Desarrollo

### 3.0 Descripción general del sistema
Ruta principal de datos:

`Teclado 4×4 → sincronización → barrido/decodificación → evento/antirrebote → FSM → registros A/B → restador → BCD → multiplexado → displays`

El reloj principal de la FPGA es de **27 MHz**. Los módulos lentos utilizan habilitaciones derivadas del reloj, manteniendo un único dominio de reloj.

### 3.1 `top.sv`
Módulo superior. Integra el generador de ticks, el sistema de calculadora y el subsistema de visualización.

Entradas principales: `clk`, `reset_n`, `rows[3:0]`.
Salidas principales: `columns[3:0]`, `an[3:0]`, `sseg[7:0]`.

### 3.2 Lectura del teclado
- `synchronizer.sv`: sincroniza las filas asíncronas con el reloj interno.
- `keypad_scanner.sv`: barre las cuatro columnas del teclado.
- `keypad_decoder.sv`: convierte fila/columna al código de tecla.
- `keypad_event.sv`: valida eventos de una sola tecla.
- `debouncer.sv`: elimina rebote mecánico.
- `keypad_frontend.sv`: integra el frente completo del teclado y entrega `key_code`/`key_press`.

### 3.3 Captura y control
- `operand_register.sv`: construye cada operando decimal dígito a dígito.
- `calculator_fsm.sv`: controla captura de A, captura de B, cálculo, despliegue y limpieza.
- `calculator_core.sv`: integra FSM, registros y aritmética.
- `calculator_system.sv`: integra el teclado con el núcleo de calculadora.

### 3.4 Aritmética
- `subtractor.sv`: implementa la resta sin usar directamente el operador `-`, mediante complemento y suma. Entrega magnitud y signo.

### 3.5 Conversión y despliegue
- `rom_reg.sv`: ROM inicializada mediante `bcdtable.txt`.
- `bcd_converter.sv`: convierte el valor binario a representación BCD.
- `disp_hex_mux.sv`: multiplexa los cuatro displays.
- `calculator_display.sv`: selecciona operando/resultado y gestiona signo y ceros a la izquierda.

### 3.6 Generación de habilitaciones
- `tick_generator.sv`: genera ticks para barrido de teclado y otras funciones lentas a partir del reloj de 27 MHz.

### 3.7 Módulos de diagnóstico
Se conservan módulos `*_diag_top.sv` para probar por separado lectura de teclado, frontend y registros durante el montaje físico.

### 3.8 Testbenches
Los testbenches están en `src/sim/`. El principal es `tb_top.sv` y verifica, entre otros casos:
- `123 - 45 = 78`.
- `45 - 123 = -78`.
- `999 - 999 = 0`.

También existen pruebas unitarias para sincronizador, debounce, scanner, decoder, eventos, registros, restador, FSM, conversión BCD, display y sistema integrado.

## 4. Consumo de recursos
La compilación previa del proyecto generó un netlist P&R con 1259 celdas, incluyendo 890 `SLICE` y 22 `IOB`. Los valores definitivos deben tomarse del nuevo `pnr_tangnano9k.log` generado al recompilar esta versión.

## 5. Problemas encontrados durante el proyecto
- Las entradas del teclado son asíncronas y requieren sincronización y antirrebote.
- La matriz del teclado requiere barrido por columnas y detección consistente de una sola tecla.
- La resta debe implementarse mediante complemento y suma, no con el operador `-`.
- El archivo ROM `bcdtable.txt` debe estar disponible durante síntesis y simulación. En esta plantilla se referencia como `../design/bcdtable.txt` porque los comandos se ejecutan desde `src/build`.
- Los displays requieren multiplexado suficientemente rápido y polaridad adecuada en las salidas físicas.

## 6. Estructura del proyecto
```text
src/
├── build/       Makefile y archivos generados
├── constr/      constraints de la Tang Nano 9K
├── design/      módulos SystemVerilog y bcdtable.txt
└── sim/         testbenches
```

## 7. Uso
Desde `src/build`:

```bash
make test       # simulación RTL principal
make synth      # síntesis
make pnr        # place & route a 27 MHz
make bitstream  # genera Proyecto_Corto_2_tangnano9k.fs
make load       # carga a la Tang Nano 9K
```

Para otro testbench:

```bash
make test TESTBENCH=../sim/tb_subtractor.sv TOP_TB=tb_subtractor
```

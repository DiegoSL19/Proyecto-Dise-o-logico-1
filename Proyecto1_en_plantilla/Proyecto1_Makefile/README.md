# Proyecto Corto I: Hamming SEC-DED con Tang Nano 9K

## 1. Abreviaturas y definiciones
- **FPGA**: Field Programmable Gate Array.
- **SEC**: Single Error Correction.
- **DED**: Double Error Detection.
- **TX**: transmisor.
- **RX**: receptor.
- **P1, P2, P4**: bits de paridad Hamming.
- **P0**: bit de paridad global para DED.

## 2. Referencias
- Enunciado del Proyecto Corto I, EL-3307 Diseño Lógico, II Semestre 2026.
- Esquemático Tang Nano 9K incluido en `doc/`.

## 3. Desarrollo

### 3.0 Descripción general del sistema
El proyecto implementa un enlace Hamming SEC-DED de 8 bits. Las entradas D0-D3 y las paridades físicas P1, P2, P4 y P0 forman la palabra:

`[7:0] = {P0, D3, D2, D1, P4, D0, P2, P1}`

El módulo `generador_error` puede invertir hasta dos posiciones seleccionadas. El módulo `receptor_core` calcula síndrome y paridad global, corrige un error sencillo y detecta un doble error. `seven_segment` realiza el despliegue hexadecimal.

### 3.1 Módulo `top_display`
Es el módulo superior del proyecto. Integra:
- entradas D0-D3;
- paridades físicas provenientes de los 74HC86;
- dos selectores de error de tres bits;
- bus externo de ocho bits;
- receptor SEC-DED;
- display TX y display RX;
- LEDs internos de síndrome y DED.

El parámetro local `MODO_TX` selecciona el uso del bus externo:
- `1'b1`: transmite `tx_interno` y mantiene loopback interno para pruebas;
- `1'b0`: libera el bus con alta impedancia y lo utiliza como entrada RX externa.

### 3.2 Módulo `generador_error`
Recibe la palabra correcta de 8 bits y dos selectores `error1_pi` y `error2_pi`. Cada selector genera una máscara de error y la salida se obtiene mediante XOR:

`codigo_po = codigo_pi ^ mascara1 ^ mascara2`

La codificación 001-111 corresponde a las posiciones 1-7 de Hamming. El código 000 significa sin error.

### 3.3 Módulo `receptor_core`
Calcula los tres bits de síndrome, la paridad global SEC-DED y la máscara de corrección. Entrega la palabra corregida y los cuatro bits de información recuperados.

### 3.4 Módulo `seven_segment`
Decodifica un valor de cuatro bits a las siete señales activas en bajo usadas por los displays de ánodo común.

### 3.5 Testbench
El testbench activo es `src/sim/TB_top_display.sv`. Verifica como mínimo:
1. dato A sin errores;
2. error sencillo en posición Hamming 3;
3. visualización del síndrome;
4. doble error en posiciones 1 y 2 y activación DED.

Desde `src/build/`:

```bash
make test
make wv
```

### 3.6 Flujo de síntesis y programación
El Makefile de la plantilla quedó configurado para este proyecto. Los comandos principales son:

```bash
make synth
make pnr
make bitstream
make load
```

También puede ejecutarse todo el flujo con:

```bash
make
```

## 4. Consumo de recursos
Completar con los resultados generados por Yosys/nextpnr después de ejecutar síntesis y P&R en el ambiente del curso.

## 5. Problemas encontrados durante el proyecto
- Corrección física de P0: la salida correcta es U1 pin 11 hacia Tang Nano pin 41.
- Se evitaron GPIO del banco de 1.8 V para señales externas de 3.3 V.
- Se reutilizó el mismo bus físico de ocho bits como TX/RX mediante alta impedancia para no consumir otros ocho GPIO.
- El selector de error de 3 bits reserva 000 para “sin error”; por ello 001-111 cubre las siete posiciones Hamming y no selecciona P0 directamente.

## Apéndices
- `doc/Tang_Nano_9k_3672_Schematic.pdf`: esquemático de la FPGA.
- `doc/legacy_hdl/`: módulos antiguos conservados únicamente como respaldo; no forman parte del build actual.
- `doc/legacy_sim/`: testbenches anteriores conservados como respaldo.

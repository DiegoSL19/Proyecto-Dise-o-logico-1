#Makefile con todo el flujo de trabajo para GOWIN. Utilizando Yosys, nextpnr, iverilog, gtkwave y openFPGALoader

#FPGA a utilizar... Esto no se debe modificar para efectos del curso.
BOARD  = tangnano9k
FAMILY = GW1N-9C
DEVICE = GW1NR-LV9QN88PC6/I5

#Nombre del proyecto.
PROYECT = proyecto1

#Fuentes de diseno activas.
#Se indican explicitamente para que los archivos antiguos guardados en doc/legacy_hdl
#no formen parte del build final.
SOURCES = ../design/top_display.sv \
          ../design/generador_error.sv \
          ../design/receptor_core.sv \
          ../design/seven_segment.sv

#Fuente de simulacion
TESTBENCH = ../sim/TB_top_display.sv

#Constraints para el proyecto
CONSTRAINTS = ../constr/proyecto1.cst

#Top del diseno y top del testbench
TOP_DESIGN = top_display
TOP_TB     = TB_top_display

#Nombre del VCD generado por el testbench
VCD_FILE = proyecto1_tb.vcd


all: load

# Synthesis
synth: ${SOURCES}
	@echo "Ejecutando la sintesis..."
	@yosys -p "read_verilog -sv ${SOURCES}; synth_gowin -top ${TOP_DESIGN} -json ${PROYECT}.json" > synthesis_${BOARD}.log 2>&1 
	@echo "COMPLETADO"

# Place and Route
pnr: synth
	@echo "Ejecutando el pnr..."
	@nextpnr-gowin --json ${PROYECT}.json --write ${PROYECT}_pnr.json --freq 27 --device ${DEVICE} --family ${FAMILY} --cst ${CONSTRAINTS} > pnr_${BOARD}.log 2>&1 
	@echo "COMPLETADO"

# Generar el Bitstream
bitstream: pnr
	@echo "Generando ${PROYECT}_${BOARD}.fs"
	@gowin_pack -d ${FAMILY} -o ${PROYECT}_${BOARD}.fs ${PROYECT}_pnr.json
	@echo "COMPLETADO"
		
#Generar vcd con icarus verilog
test: ${SOURCES} ${TESTBENCH}
	@iverilog -o ${PROYECT}_test.o -s ${TOP_TB} -g2005-sv ${TESTBENCH} ${SOURCES}
	@vvp ${PROYECT}_test.o 
	
#Visualizar los diagramas de tiempo con GTKWave
wv: test
	gtkwave ${VCD_FILE} 
        
# Cargar el bitstream en la FPGA
load: bitstream
	openFPGALoader -b ${BOARD} ${PROYECT}_${BOARD}.fs 

.PHONY: load wv test synth pnr bitstream


# ============================================================
# TESTBENCHES DEL TRANSMISOR
# ============================================================

test_tx1:
	iverilog -o tx1.o -s TB_TX_01_sin_error -g2005-sv \
	../sim/TB_TX_01_sin_error.sv \
	../design/top_display.sv \
	../design/generador_error.sv \
	../design/receptor_core.sv \
	../design/seven_segment.sv
	vvp tx1.o


test_tx2:
	iverilog -o tx2.o -s TB_TX_02_generador_errores -g2005-sv \
	../sim/TB_TX_02_generador_errores.sv \
	../design/top_display.sv \
	../design/generador_error.sv \
	../design/receptor_core.sv \
	../design/seven_segment.sv
	vvp tx2.o


# ============================================================
# TESTBENCHES DEL RECEPTOR
# ============================================================

test_rx1:
	iverilog -o rx1.o -s TB_RX_01_sin_error -g2005-sv \
	../sim/TB_RX_01_sin_error.sv \
	../design/receptor_core.sv
	vvp rx1.o


test_rx2:
	iverilog -o rx2.o -s TB_RX_02_error_simple_pos3 -g2005-sv \
	../sim/TB_RX_02_error_simple_pos3.sv \
	../design/receptor_core.sv
	vvp rx2.o


test_rx3:
	iverilog -o rx3.o -s TB_RX_03_error_P0 -g2005-sv \
	../sim/TB_RX_03_error_P0.sv \
	../design/receptor_core.sv
	vvp rx3.o


test_rx4:
	iverilog -o rx4.o -s TB_RX_04_doble_error -g2005-sv \
	../sim/TB_RX_04_doble_error.sv \
	../design/receptor_core.sv
	vvp rx4.o


# ============================================================
# EJECUTAR TODOS LOS TESTBENCHES
# ============================================================

test_all: test_tx1 test_tx2 test_rx1 test_rx2 test_rx3 test_rx4
	@echo "========================================="
	@echo "TODOS LOS TESTBENCHES FUERON EJECUTADOS"
	@echo "========================================="
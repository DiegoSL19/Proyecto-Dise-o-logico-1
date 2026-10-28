# Flujo de trabajo para Tang Nano 9K con Yosys, nextpnr-gowin,
# iverilog, GTKWave y openFPGALoader.

BOARD  = tangnano9k
FAMILY = GW1N-9C
DEVICE = GW1NR-LV9QN88PC6/I5

PROYECT = Proyecto_Corto_2

# Fuentes de diseño de la plantilla.
SOURCES := $(wildcard ../design/*.v ../design/*.sv)

# Testbench principal del sistema completo. Puede sobrescribirse desde consola,
# por ejemplo: make test TESTBENCH=../sim/tb_subtractor.sv TOP_TB=tb_subtractor
TESTBENCH ?= ../sim/tb_top.sv

CONSTRAINTS = ../constr/tangnano9k.cst

TOP_DESIGN = top
TOP_TB ?= tb_top

# tb_top actualmente imprime resultados PASS/FAIL y no genera VCD.
# Si se agrega $dumpfile/$dumpvars a un TB, se puede indicar aquí o por consola.
VCD_FILE ?= Proyecto_Corto_2.vcd

all: synth pnr bitstream load

synth: ${SOURCES}
	@echo "Ejecutando la sintesis..."
	@yosys -p "read_verilog -sv ${SOURCES}; synth_gowin -top ${TOP_DESIGN} -json ${PROYECT}.json" > synthesis_${BOARD}.log 2>&1
	@echo "COMPLETADO"

pnr: ${PROYECT}.json
	@echo "Ejecutando el pnr..."
	@nextpnr-gowin --json ${PROYECT}.json --write ${PROYECT}_pnr.json --freq 27 --device ${DEVICE} --family ${FAMILY} --cst ${CONSTRAINTS} > pnr_${BOARD}.log 2>&1
	@echo "COMPLETADO"

bitstream: ${PROYECT}_pnr.json
	@echo "Generando ${PROYECT}_${BOARD}.fs"
	@gowin_pack -d ${FAMILY} -o ${PROYECT}_${BOARD}.fs ${PROYECT}_pnr.json
	@echo "COMPLETADO"

test: ${SOURCES} ${TESTBENCH}
	@iverilog -o ${PROYECT}_test.o -s ${TOP_TB} -g2005-sv ${TESTBENCH} ${SOURCES}
	@vvp ${PROYECT}_test.o

wv: ${VCD_FILE}
	gtkwave ${VCD_FILE}

load: ${PROYECT}_${BOARD}.fs
	openFPGALoader -b ${BOARD} ${PROYECT}_${BOARD}.fs

clean:
	rm -f *.json *.fs *.log *.o *.vcd

.PHONY: all synth pnr bitstream test wv load clean
.INTERMEDIATE: ${PROYECT}_pnr.json ${PROYECT}.json

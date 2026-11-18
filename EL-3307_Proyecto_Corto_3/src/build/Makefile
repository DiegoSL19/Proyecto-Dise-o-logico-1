# Ejecutar desde este directorio. Ningun objetivo programa la FPGA.
GOWIN_SH ?= C:/Gowin/Gowin_V1.9.11.03_Education_x64/IDE/bin/gw_sh.exe

REUSED = synchronizer.sv debouncer.sv subtractor.sv tick_generator.sv rom_reg.sv bcd_converter.sv disp_hex_mux.sv
SOURCES = $(wildcard ../design/*.sv) $(addprefix ../../../EL-3307_Proyecto_Corto_2/src/design/,$(REUSED))
CONSTRAINTS = ../constr/vending_top.cst ../constr/vending_top.sdc

.PHONY: all gowin test
all: gowin

# El Tcl selecciona vending_top y realiza sintesis, PnR y STA a 27 MHz.
gowin: $(SOURCES) $(CONSTRAINTS) vending_top_gowin.tcl
	"$(GOWIN_SH)" vending_top_gowin.tcl

# Ejecutar todos los bancos RTL de los Proyectos Cortos 2 y 3.
test:
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File ../sim/run_questa.ps1

# Ejecutar desde este directorio. Ningun objetivo programa la FPGA.
GOWIN_SH ?= C:/Gowin/Gowin_V1.9.11.03_Education_x64/IDE/bin/gw_sh.exe

SOURCES = $(wildcard ../design/*.sv) $(wildcard ../design/reused/*.sv)
ROM = ../design/reused/bcdtable.txt
CONSTRAINTS = ../constr/vending_top.cst ../constr/vending_top.sdc

.PHONY: all gowin test
all: gowin

# El Tcl selecciona vending_top y realiza sintesis, PnR y STA a 27 MHz.
gowin: $(SOURCES) $(CONSTRAINTS) $(ROM) vending_top_gowin.tcl
	"$(GOWIN_SH)" vending_top_gowin.tcl

# Ejecutar todos los bancos RTL locales del Proyecto Corto 3.
test:
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File ../sim/run_questa.ps1

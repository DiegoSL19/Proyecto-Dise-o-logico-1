# Notas de migración a la plantilla con Makefile

Se tomó como base la estructura de `Proyecto.zip` y se integró el diseño activo de `Proyecto1(1).zip`.

## Archivos activos del build
- `src/design/top_display.sv`
- `src/design/generador_error.sv`
- `src/design/receptor_core.sv`
- `src/design/seven_segment.sv`
- `src/constr/proyecto1.cst`
- `src/sim/TB_top_display.sv`
- `src/build/Makefile`

## Cambio de limpieza realizado
En `generador_error.sv` se eliminaron dos líneas antiguas que intentaban asignar `tx_po = tx_interno` dentro del módulo, aunque esas señales no pertenecen a su interfaz. La salida física se mantiene correctamente en `top_display.sv`.

Los módulos y testbenches antiguos se conservaron en `doc/legacy_*` para no perder trabajo, pero no son compilados por el Makefile.

## Ajuste del Makefile
La plantilla original declaraba `pnr` dependiente directamente de `proyecto1.json` y `bitstream` de `proyecto1_pnr.json`, sin reglas explícitas para construir esos archivos cuando se ejecutaban los objetivos por separado. Se conservaron los mismos comandos, pero se encadenaron los objetivos como `synth -> pnr -> bitstream -> load`, de modo que `make`, `make pnr`, `make bitstream` y `make load` tengan dependencias coherentes.

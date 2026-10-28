# Notas de migración a la plantilla EL-3307

- Se copiaron los módulos `.sv` funcionales a `src/design/`.
- Se copiaron todos los testbenches a `src/sim/`.
- Se copió el archivo de constraints a `src/constr/tangnano9k.cst`.
- `bcdtable.txt` quedó en `src/design/` y se ajustaron sus rutas a `../design/bcdtable.txt` para ejecutar desde `src/build/`.
- El `Makefile` quedó configurado con `PROYECT=Proyecto_Corto_2`, `TOP_DESIGN=top`, `TOP_TB=tb_top` y frecuencia de P&R de 27 MHz.
- Se excluyeron los tres archivos fuente vacíos del proyecto original (`bin_to_bcd.sv`, `display_mux.sv`, `sevenseg_decoder.sv`).
- No se copiaron productos de compilación antiguos (`.json`, `.fs`, `.vvp`, `.sdf`, netlists post-route), porque la plantilla está preparada para regenerarlos y su `.gitignore` los trata como archivos de build.
- Se eliminó el directorio `.git` heredado de la plantilla para evitar conservar el remoto del repositorio original del profesor. Si se requiere control de versiones, ejecutar `git init` en la raíz.

# Unico reloj del sistema: oscilador integrado de 27 MHz.
create_clock -name clk_27mhz -period 37.037037 [get_ports {clk}]

# Los contactos mecanicos no tienen relacion de fase con el reloj.
# Se excluye su llegada externa, no el trayecto entre los registros internos.
set_false_path -from [get_ports {start_n restart_n product_sw[0] product_sw[1] coins_sw[0] coins_sw[1] coins_sw[2]}]

# S1 afirma reset de forma asincrona; su liberacion usa dos registros.
# Los trayectos desde esos registros hacia la logica interna siguen analizandose.
set_false_path -from [get_ports {reset_n}]

# Los LED y el display no tienen un receptor con reloj externo.
# Solo se excluyen trayectos que terminan en sus pines de salida.
set_false_path -to [get_ports {delivery_led_n[0] delivery_led_n[1] delivery_led_n[2] empty_led_n[0] empty_led_n[1] empty_led_n[2] refund_led an[0] an[1] an[2] an[3] sseg[0] sseg[1] sseg[2] sseg[3] sseg[4] sseg[5] sseg[6] sseg[7]}]

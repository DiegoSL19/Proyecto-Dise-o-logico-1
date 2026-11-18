# Implementacion independiente para simular parametros reducidos sin editar RTL.
set build_dir [file dirname [file attributes [file normalize [info script]] -shortname]]
set project_dir [file attributes [file join $build_dir ../..] -shortname]
if {[info exists env(VENDING_NETLIST_OUTPUT)]} {
    set output_dir $env(VENDING_NETLIST_OUTPUT)
} else {
    set output_dir [file join $project_dir work netlist_[clock milliseconds]]
}
file mkdir $output_dir
set output_dir [file attributes [file normalize $output_dir] -shortname]
set reusable_dir [file join $project_dir src design reused]

# Mismos 512 datos usados por PC3; la tabla local de 1024 no se modifica.
file mkdir [file join $output_dir design]
set rom_input [open [file join $reusable_dir bcdtable.txt] r]
set rom_lines [split [string trim [read $rom_input]] "\n"]
close $rom_input
if {[llength $rom_lines] != 1024} {
    error "Expected 1024 entries in the original BCD table"
}
set rom_output [open [file join $output_dir design bcdtable.txt] w]
puts $rom_output [join [lrange $rom_lines 0 511] "\n"]
close $rom_output

# Solo este envoltorio generado en work usa valores de simulacion.
set wrapper_path [file join $output_dir vending_verify_top.sv]
set wrapper_file [open $wrapper_path w]
puts $wrapper_file {module vending_verify_top (
    input logic clk, reset_n, restart_n, start_n,
    input logic [1:0] product_sw,
    input logic [2:0] coins_sw,
    output logic [2:0] delivery_led_n, empty_led_n,
    output logic refund_led,
    output logic [3:0] an,
    output logic [7:0] sseg
);
    vending_top #(
        .DEBOUNCE_N(4), .REFUND_CYCLES(26'd256), .DISPLAY_DIV(3),
        .SEGMENTS_ACTIVE_LOW(1'b0), .DIGITS_ACTIVE_LOW(1'b0)
    ) design_inst (
        .clk(clk), .reset_n(reset_n), .restart_n(restart_n), .start_n(start_n),
        .product_sw(product_sw), .coins_sw(coins_sw),
        .delivery_led_n(delivery_led_n), .empty_led_n(empty_led_n),
        .refund_led(refund_led), .an(an), .sseg(sseg)
    );
endmodule}
close $wrapper_file

create_project -name vending_verify_top -dir $output_dir \
    -pn GW1NR-LV9QN88PC6/I5 -device_version C -force
set_device -name GW1NR-9C -device_version C GW1NR-LV9QN88PC6/I5
add_file -type verilog $wrapper_path
foreach source [lsort [glob [file join $project_dir src design *.sv]]] {
    add_file -type verilog $source
}
foreach reusable {synchronizer.sv debouncer.sv subtractor.sv tick_generator.sv \
                  rom_reg.sv bcd_converter.sv disp_hex_mux.sv} {
    add_file -type verilog [file join $reusable_dir $reusable]
}
add_file -type cst [file join $project_dir src constr vending_top.cst]
add_file -type sdc [file join $project_dir src constr vending_top.sdc]
set_option -top_module vending_verify_top
set_option -verilog_std sysv2017
set_option -output_base_name vending_verify_top
set_option -global_freq 27
set_option -auto_constraint_io 0
set_option -timing_driven 1
set_option -gen_text_timing_rpt 1
set_option -gen_verilog_sim_netlist 1
set_option -gen_sdf 1
run syn
run pnr
puts "VERIFY_PROJECT_DIR=[pwd]"
exit

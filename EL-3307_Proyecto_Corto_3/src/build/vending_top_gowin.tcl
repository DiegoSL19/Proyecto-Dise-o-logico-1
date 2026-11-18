# Tang Nano 9K: synthesis, place/route and static timing only.
# Launch from any directory with gw_sh.exe <path>/vending_top_gowin.tcl.
# The project and generated files stay in Proyecto Corto 3/work.
# Gowin's project-name check rejects non-ASCII parent folders on Windows.
# Use existing 8.3 aliases; all aliases refer to the same original files.
set build_dir [file dirname [file attributes [file normalize [info script]] -shortname]]
set project_dir [file attributes [file join $build_dir ../..] -shortname]
set output_dir [file join $project_dir work gowin_vending_top]
set reusable_dir [file normalize [file join $project_dir .. \
    EL-3307_Proyecto_Corto_2 src design]]
set reusable_sources {synchronizer.sv debouncer.sv subtractor.sv \
    tick_generator.sv rom_reg.sv bcd_converter.sv disp_hex_mux.sv}

foreach constraint {vending_top.cst vending_top.sdc} {
    set constraint_path [file join $project_dir src constr $constraint]
    if {![file isfile $constraint_path]} {
        error "Missing constraint: $constraint_path"
    }
}

foreach reusable $reusable_sources {
    if {![file isfile [file join $reusable_dir $reusable]]} {
        error "Missing reusable source: $reusable"
    }
}
set rom_source [file join $reusable_dir bcdtable.txt]
if {![file isfile $rom_source]} {
    error "Missing BCD ROM: $rom_source"
}

# PC3 uses a 9-bit ROM address. Keep the original table intact and stage
# its first 512 entries; Gowin warns if the file exceeds the declared depth.
file mkdir [file join $output_dir design]
set rom_input [open $rom_source r]
set rom_lines [split [string trim [read $rom_input]] "\n"]
close $rom_input
if {[llength $rom_lines] != 1024} {
    error "Expected 1024 entries in the original BCD table"
}
set rom_output [open [file join $output_dir design bcdtable.txt] w]
puts $rom_output [join [lrange $rom_lines 0 511] "\n"]
close $rom_output

# Version C is the device revision used by the Tang Nano 9K.
create_project -name vending_top -dir $output_dir \
    -pn GW1NR-LV9QN88PC6/I5 -device_version C -force
set_device -name GW1NR-9C -device_version C GW1NR-LV9QN88PC6/I5

# create_project creates the named subdirectory. Input paths are relative;
# Gowin may serialize their absolute 8.3 spellings in the generated GPRJ.
cd [file join $output_dir vending_top]
foreach source [lsort [glob ../../../src/design/*.sv]] {
    add_file -type verilog $source
}
foreach reusable $reusable_sources {
    add_file -type verilog [file join ../../../../EL-3307_Proyecto_Corto_2 \
        src design $reusable]
}
add_file -type cst ../../../src/constr/vending_top.cst
add_file -type sdc ../../../src/constr/vending_top.sdc

set_option -top_module vending_top
set_option -verilog_std sysv2017
set_option -output_base_name vending_top
set_option -global_freq 27
set_option -auto_constraint_io 0
set_option -timing_driven 1
set_option -gen_text_timing_rpt 1
set_option -gen_verilog_sim_netlist 1
set_option -gen_sdf 1

# Export options for inspection; neither command programs a connected board.
saveto [file join $output_dir vending_top_options.tcl]
run syn
run pnr
exit

# --------------------------------------------------------------------------
#
# timing_paths.tcl - list the worst setup paths of the last compilation
#
# Run automatically after every compilation by post_flow.tcl (the project's
# post-flow script, set in Arcade-Midway-Y-Unit.qsf). By hand, from the project
# folder and without recompiling:
#   quartus_sta -t tools/timing_paths.tcl
# (quartus_sta is in the Quartus bin64 folder, e.g.
#  C:\intelFPGA_lite\17.0\quartus\bin64\quartus_sta.exe)
#
# Writes output_files/Arcade-Midway-Y-Unit.paths.txt: a one-line summary of the
# 100 worst setup paths of every clock, then the full detail of the 10 worst.
# The compilation's own .sta.rpt also shows the worst path of each clock now
# (TIMEQUEST_DO_REPORT_TIMING in Arcade-Midway-Y-Unit.qsf).
#
# --------------------------------------------------------------------------

set project  "Arcade-Midway-Y-Unit"
set out_file "output_files/$project.paths.txt"

project_open $project -revision $project
create_timing_netlist
read_sdc
update_timing_netlist

file delete -force $out_file
foreach_in_collection clk [all_clocks] {
	set name [get_clock_info -name $clk]
	report_timing -setup -to_clock $name -npaths 100 -detail summary -file $out_file -append
}
report_timing -setup -npaths 10 -detail full_path -file $out_file -append

delete_timing_netlist
project_close
puts "timing_paths.tcl: wrote $out_file"

# --------------------------------------------------------------------------
#
# release.tcl - Quartus post-flow script: file the finished core
#
# After a successful compilation, renames output_files/<revision>.rbf to
# <revision>_YYYYMMDD.rbf (the local date) and moves it to releases/. A second
# build on the same day replaces that day's file. The revision is
# Arcade-Midway-Y-Unit (the core, Arcade-Midway-Y-Unit_YYYYMMDD.rbf) or
# Arcade-Midway-Y-Unit_test (the test project, Arcade-Midway-Y-Unit_test_YYYYMMDD.rbf),
# so a test core and a production core can sit in one folder.
#
# Run by post_flow.tcl, which the project's .qsf hooks up as the
# project's one post-flow script:
#   set_global_assignment -name POST_FLOW_SCRIPT_FILE "quartus_sh:post_flow.tcl"
# (it can still be hooked up on its own as "quartus_sh:release.tcl"). Quartus
# runs the script from the project folder with
#   $quartus(args) = {flow project revision}.
#
# A compilation that failed leaves no new core: the script only takes an .rbf
# written after this run's Analysis & Synthesis report, so a core left over
# from an earlier run is never filed by mistake.
#
# (Same script as Arcade-ITech8's, with this core's names.)
#
# --------------------------------------------------------------------------

set release_revisions {Arcade-Midway-Y-Unit Arcade-Midway-Y-Unit_test}
set output_dir        "output_files"
set release_dir       "releases"

proc release_msg {type text} {
	if {[catch {post_message -type $type "release.tcl: $text"}]} {
		puts "release.tcl: $text"
	}
}

proc release_core {revision} {
	global output_dir release_dir

	set rbf [file join $output_dir "$revision.rbf"]
	set map [file join $output_dir "$revision.map.rpt"]

	if {![file exists $rbf]} {
		release_msg warning "no $rbf; nothing to release"
		return
	}
	if {[file exists $map] && [file mtime $rbf] < [file mtime $map]} {
		release_msg warning "$rbf is older than this run's synthesis report; not released"
		return
	}

	set stamp  [clock format [clock seconds] -format %Y%m%d]
	set target [file join $release_dir "${revision}_${stamp}.rbf"]

	file mkdir $release_dir
	file rename -force $rbf $target
	release_msg info "released [file normalize $target]"
}

set revision [lindex $quartus(args) 2]

if {[lsearch -exact $release_revisions $revision] >= 0} {
	if {[catch {release_core $revision} err]} {
		release_msg error "could not release the core: $err"
	}
}

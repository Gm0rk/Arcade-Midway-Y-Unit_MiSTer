# --------------------------------------------------------------------------
#
# post_flow.tcl - Quartus post-flow script of Arcade-Midway-Y-Unit
#
# Quartus runs one post-flow script per project, so this one does the jobs in
# turn after a compilation:
#
#   1. release.tcl: files the finished core under releases/.
#   2. tools/timing_paths.tcl: writes output_files/Arcade-Midway-Y-Unit.paths.txt
#      (the 100 worst setup paths of every clock, then the 10 worst in full).
#      It is run with quartus_sta, which takes a minute or two.
#
# Hooked up in Arcade-Midway-Y-Unit.qsf:
#   set_global_assignment -name POST_FLOW_SCRIPT_FILE "quartus_sh:post_flow.tcl"
# Quartus runs it from the project folder with
#   $quartus(args) = {flow project revision}.
#
# The paths file is written for every compilation that got as far as the
# timing analysis, whether timing is met or not (that is when it is wanted).
# A compilation that failed earlier has no new timing report, so the script
# leaves the last paths file alone and says so. A problem in either job is a
# warning in the Messages window; it never fails the build.
#
# By hand, without recompiling: quartus_sta -t tools/timing_paths.tcl
#
# --------------------------------------------------------------------------

set post_revision "Arcade-Midway-Y-Unit"
set post_dir      [file dirname [file normalize [info script]]]

proc post_msg {type text} {
	if {[catch {post_message -type $type "post_flow.tcl: $text"}]} {
		puts "post_flow.tcl: $text"
	}
}

# quartus_sta next to the quartus_sh that is running this script, else on the PATH
proc post_sta_exe {} {
	global quartus
	if {[info exists quartus(binpath)]} {
		foreach name {quartus_sta.exe quartus_sta} {
			set path [file join $quartus(binpath) $name]
			if {[file isfile $path]} {
				return $path
			}
		}
	}
	return "quartus_sta"
}

proc post_timing_paths {revision} {
	global post_dir

	set script  [file join $post_dir tools timing_paths.tcl]
	set summary [file join output_files "$revision.sta.summary"]
	set map     [file join output_files "$revision.map.rpt"]
	set paths   [file join output_files "$revision.paths.txt"]

	if {![file exists $script]} {
		post_msg warning "no $script; timing paths not listed"
		return
	}
	if {![file exists $summary]} {
		post_msg warning "no $summary; the compilation did not reach the timing analysis, timing paths not listed"
		return
	}
	if {[file exists $map] && [file mtime $summary] < [file mtime $map]} {
		post_msg warning "$summary is older than this run's synthesis report; timing paths not listed"
		return
	}

	set started [clock seconds]
	post_msg info "listing the worst timing paths (takes a minute or two)"
	set failed [catch {exec [post_sta_exe] -t $script 2>@1} output]

	if {![file exists $paths] || [file mtime $paths] < $started} {
		set lines [split [string trim $output] "\n"]
		set tail  [join [lrange $lines end-4 end] " | "]
		post_msg warning "timing_paths.tcl wrote no new $paths: $tail"
		return
	}
	if {$failed} {
		post_msg warning "quartus_sta reported a problem after writing $paths"
	}
	post_msg info "wrote [file normalize $paths]"
}

# work from the project folder, as release.tcl and timing_paths.tcl expect
cd $post_dir

# 1. file the finished core
if {[catch {source [file join $post_dir release.tcl]} err]} {
	post_msg warning "release.tcl failed: $err"
}

# 2. list the worst timing paths
if {[lindex $quartus(args) 2] eq $post_revision} {
	if {[catch {post_timing_paths $post_revision} err]} {
		post_msg warning "could not list the timing paths: $err"
	}
}

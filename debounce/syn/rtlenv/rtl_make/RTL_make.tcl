# 
# Copyright (c) 2015-2018 Schweitzer Engineering Laboratories, Inc.
# SEL Confidential
#
# Description:
#  Make file to build, compile, simulate and report coverage for RTL tests.
#
# Details:
#  Refer to the readme.md file in bitbucket for a full description:
#  https://bitbucket.metro.ad.selinc.com/projects/CCRTLTOOLS/repos/rtl_make/browse
#
transcript off

#-------------------------------------------------------------------------------
# Initial set up
#-------------------------------------------------------------------------------

# Identify the simulation environment.
variable is_aldec        [expr [info exists aldec]]
variable is_aldec_vsimsa [expr $is_aldec && [info exists BatchMode]]
variable is_aldec_gui    [expr $is_aldec && !$is_aldec_vsimsa]
variable is_modelsim     [info exists vsimPriv]
variable is_modelsim_vsim [expr [batch_mode] && $is_modelsim]
variable is_modelsim_gui [expr ![batch_mode] && $is_modelsim]

# Further suppress modelsim prints since "transcript off" doesn't
# apply to anything outside this file (e.g. RTL_sim_lib calls)
if {$is_modelsim} {
  transcript quietly
}
# Display note on how to exit the simulation from command line
if {$is_modelsim_vsim} {
  puts "\n-- Press CTRL+BREAK to break out of the simulation --\n"
} elseif {$is_aldec_vsimsa} {
  puts "\n-- Press ESC to break out of the simulation --\n"
}

# Keep track of execution time.
set timestart [clock seconds]

# Configure Error Handling
if {$is_aldec_vsimsa} {
  # Utilize Active-HDL's exitonerror variable to drop out of Active-HDL when an
  #  error from running this script occurs.
  set exitonerror 1
} elseif {$is_aldec_gui} {
  onerror {
    puts "RTLMAKE: **** ERROR DETECTED - Aborting Simulation ****"
    catch {close $rtlmake_log}
    transcript to -off
    abort
  }
} elseif {$is_modelsim_vsim} {
  # Utilize ModelSim's onerror macro to drop out of ModelSim when an error 
  #  from running this script occurs.
  onerror {
    puts "RTLMAKE: **** ERROR DETECTED - Exiting with Exit Code 255 ****"
    quit -code 255
  }
} elseif {$is_modelsim_gui} {
  # Utilize ModelSim's onerror macro to abort the simulation when an error 
  #  from running this script occurs.
  onerror {
    puts "RTLMAKE: **** ERROR DETECTED - Aborting Simulation ****"
    catch {close $rtlmake_log}
    transcript file ()
    abort
  } 
}

# Determine the absolute path of this script and that of the sourced library.
if {$is_aldec_vsimsa} {
  set rtl_make_path [file normalize $argv0]
} elseif {$is_aldec_gui} {
  # Get RTL_Make PATH from compiler: search stack for "do rtl_make" string
  set n 0
  set errnum 0
  set stackinfo {cmd 0}  ; # lowest stack level
  # Search the trace log for the "do rtl_make.tcl" phrase, which has the path:
  while {(($errnum != 1) && [expr ![dict exists $stackinfo file]])}  {
    set stackinfo [info frame $n]
    # puts "RTLMAKE: $n: $stackinfo"  ;# Shows the stack trace; uncomment for debug
    incr n
    set errnum [catch {info frame $n}]
  }
  set rtl_make_path [dict get $stackinfo file]      ;# Assign path
  set rtl_make_path [file normalize $rtl_make_path]
} elseif {$is_modelsim_gui} {
  # Get RTL_Make PATH from compiler: search stack for "do rtl_make" string
  set n 0
  set errnum 0
  set stackinfo {cmd 0}  ; # lowest stack level
  # Search the trace log for the "do rtl_make.tcl" phrase, which has the path:
  while {($errnum != 1) && 
         ([string match -nocase do [string range [dict get $stackinfo cmd] 0 1]] == 0)} {
    set stackinfo [info frame $n]
    # puts "RTLMAKE: $n: $stackinfo"  ;# Shows the stack trace; uncomment for debug
    incr n
    set errnum [catch {info frame $n}]
  }
  set rtl_make_path [lindex [dict get $stackinfo cmd] 1 ]   ;# Assign path
  set rtl_make_path [file normalize $rtl_make_path]
} elseif {$is_modelsim_vsim} {
  # Modelsim has a slightly different $argv on Linux vs Window.  Rather
  # than assume an index, we loop through all of argv until we find
  # RTL_make.tcl as part of the string.
  set rtl_make_path ""
  foreach arg $argv {
    if { [string first "RTL_make.tcl" $arg] != -1 } {
      set rtl_make_path $arg
    }
  }

  # We should be able to figure this out.  But if not, error out.
  if { [string length $rtl_make_path] == 0 } {
    puts "RTLMAKE: **** ERROR DETECTED - Cannot determine RTL_make.tcl location ****"
    quit -code 255
  }

  # Now, extract the path to RTL_make.tcl
  set rtl_make_path [lindex [split $rtl_make_path " "] 1]
  set rtl_make_path [file normalize $rtl_make_path]
}


set sim_lib [file join [file dirname $rtl_make_path] RTL_sim_lib.tcl]

# Include the RTL sim library.
source $sim_lib

# Load the garbage file. Initially assume that either .garbage exists or that
# the folder is clean. The other command may be used to clean view-private
# files if this one does not do what the users expect.
dict set trash_tracker contents [RTL_sim_lib::ls_recurse ..]

dict set trash_tracker garbage {}
if {[file exists ".garbage"]} {
  set fh [open .garbage r]
  dict set trash_tracker garbage  [read $fh]
  close $fh
}

# Parse the command line for options.
RTL_sim_lib::parse_command_line

# Identify which steps to run, as specified by the command line options. Note,
# multiple actions can take place in a single command.
set help_opt      [dict exists $RTL_sim_lib::sim_options help]
set build_opt     [dict exists $RTL_sim_lib::sim_options build]
set compile_opt   [dict exists $RTL_sim_lib::sim_options compile]
set simulate_opt  [dict exists $RTL_sim_lib::sim_options simulate]
set verify_opt    [dict exists $RTL_sim_lib::sim_options verify]
set coverage_opt  [dict exists $RTL_sim_lib::sim_options report_coverage]
set clean_opt     [dict exists $RTL_sim_lib::sim_options clean]
set before_all_opt [dict exists $RTL_sim_lib::sim_options before_all]
set after_all_opt  [dict exists $RTL_sim_lib::sim_options after_all]

#-------------------------------------------------------------------------------
# Begin main execution.
#-------------------------------------------------------------------------------
if {$help_opt} {
  # Read this script and print the comments as help.
  puts "#\t\t-------------------------------------------------------"
  puts "#\t\t   RTLMAKE: <INSERT PATH TO 'TOOLS' REPOSITORY>/tools/tcl/RTL_make.tcl help:"
  puts "#\t\t-------------------------------------------------------"
  set fh [open $rtl_make_path r]
  while {[gets $fh line]} {
    puts "$line"
  }
  close $fh

} else {
  # Create an environment log file to record simulation details for future processing
  # The log file follows the TOML format.  TOML was chosen due to being easy to 
  # read by humans and easy to parse in python.
  set rtlmake_log [open "rtl_make.log" "w"]
  puts $rtlmake_log "\[environment\]"
  
  # Record the simulator in the environment log
  if {$is_modelsim} { 
    puts $rtlmake_log "  tool = \"modelsim\"" 
    puts $rtlmake_log "  version = \"[eval vsimVersionString]\"" 
  }
  if {$is_aldec} { 
    puts $rtlmake_log "  tool = \"activehdl\"" 
    puts $rtlmake_log "  version = \"[lindex [split [exec vsimsa -tcl vsimversion] \n] end]\""
  }

  # Source the test parameters now.
  set success [catch {source ./test_parameters.tcl} err_msg]
  if {$success != 0} {
    puts $rtlmake_log "  test_parameters = \"error\""
    error "RTLMAKE: Loading \"test_parameters.tcl\" failed. Got error message: $err_msg"
  } else {
    puts $rtlmake_log "  test_parameters = \"success\""
  }
  
  # Set default actions to run if none were specified.
  if { !($build_opt || $compile_opt || $simulate_opt || $verify_opt || $coverage_opt || $clean_opt || $before_all_opt || $after_all_opt)} {
    set build_opt true
    set compile_opt true
    set simulate_opt true
    #By default enable verify when the command dictionary exists or when no
    #after_all_commands exists.  Simulations must have either a verification script
    #or an after_all_commands section that does verification.
    set verify_opt [expr {[info exists command_dictionary] || ![info exists after_all_commands]}]
    set coverage_opt true
    #Enable before_all and after_all when they are defined in test_parameters.tcl
    set before_all_opt [info exists before_all_commands]
    set after_all_opt [info exists after_all_commands]
  }
  close $rtlmake_log

  # Run before_all if specified in test_parameters and doing a full run
  # Start record for the before_all section
  set rtlmake_log [open "rtl_make.log" "a"]
  puts $rtlmake_log {}
  puts $rtlmake_log "\[before_all\]"
  if {$before_all_opt} {
    puts "RTLMAKE: Running before_all_commands."
    set success [catch {RTL_sim_lib::exec_cmd_dictionary $before_all_commands before_all_commands before_all} err_msg]
    if {$success != 0} {
      puts $rtlmake_log "  before_all = \"error\""
      error $err_msg
    } else {
      puts $rtlmake_log "  before_all = \"success\""
    }
  } else {
    puts $rtlmake_log "  before_all = \"skipped\""
  }
  close $rtlmake_log
  
  # Start the testbenches section of the environment log
  set rtlmake_log [open "rtl_make.log" "a"]
  puts $rtlmake_log {}
  puts $rtlmake_log "\[testbenches\]"

  # Find all the test benches and run the chosen actions on them.
  foreach test_bench $RTL_sim_lib::tb_src_list {
    # Determine which test bench is running.
    set tb_name [file rootname [lindex [file split $test_bench] end]]

    puts "----------------------------------------------------------------------"
    
    # Start record for this testbench in the environment log
    puts $rtlmake_log {}
    puts $rtlmake_log "  \[testbenches.$tb_name\]"
    
    # Write a list of the tests associated with this testbench
    if {[llength $RTL_sim_lib::tb_src_list] > 1  && [info exists simulation_map]} {
      #More than one testbench exists so we need to use the simulation map
      if {[llength [dict get $simulation_map $tb_name]] == 0} {
        # A simulation map exists, but this testbench does not have any tests
        puts $rtlmake_log "    known_testno = \[\]"
      } else {
        # A simulation map exists for this testbench
        puts $rtlmake_log "    known_testno = \[\"[join [dict get $simulation_map $tb_name] "\",\""]\"\]"
      }
    } elseif {[info exists test_parameters]} {
      # No simulation map exists, assume all defined tests apply to this testbench
      puts $rtlmake_log "    known_testno = \[\"[join [dict keys $test_parameters] "\",\""]\"\]"
    } else {
      # If we end up here we did not specify a test number and no simulation_map
      # exists and no test_parameters exits.  This is an invalid config and 
      # RTL_make will probably fail somewhere else, but we will log something 
      # anyway.
      puts $rtlmake_log "    known_testno = \[\]"
    }
    
    # Determine if we should execute commands on this testbench
    # See puts statements for explanation of each reason for skipping a testbench
    if {[info exists simulation_map] && \
        [llength [dict get $simulation_map $tb_name]] == 0} {
      puts $rtlmake_log "    testno = \[\"skipped\"\]"
      puts "RTLMAKE: Skipping run for '$tb_name' since there are no tests associated with it."
    } elseif {[info exists simulation_map] && \
              [dict exists $simulation_map $tb_name] && \
              [dict exists $RTL_sim_lib::sim_options testno] && \
              [lsearch [dict get $simulation_map $tb_name] [dict get $RTL_sim_lib::sim_options testno]]<0} {
      puts $rtlmake_log "    testno = \[\"skipped\"\]"
      puts "RTLMAKE: Skipping run for '$tb_name' since the requested testno is not associated with it."
    } elseif {[dict exists $RTL_sim_lib::sim_options build] && \
              [dict get $RTL_sim_lib::sim_options build] != $tb_name} {
      puts $rtlmake_log "    testno = \[\"skipped\"\]"
      puts "RTLMAKE: Skipping run for '$tb_name' since it does not match the requested testbench."
    } elseif {[dict exists $RTL_sim_lib::sim_options testbench] && \
              [dict get $RTL_sim_lib::sim_options testbench] != $tb_name} {
      puts $rtlmake_log "    testno = \[\"skipped\"\]"
      puts "RTLMAKE: Skipping run for '$tb_name' since it does not match the requested testbench."
    } else {
      puts "RTLMAKE: Starting run for '$tb_name'."
      #Make a log entry for which testno is being executed.
      if {[dict exists $RTL_sim_lib::sim_options testno]} {
        #We specified a test number, write out just that value
        puts $rtlmake_log "    testno = \[\"[dict get $RTL_sim_lib::sim_options testno]\"\]"
      } elseif {[llength $RTL_sim_lib::tb_src_list] > 1 && [info exists simulation_map]} {
        #We are running all testno so write out all values in the simulation map
        puts $rtlmake_log "    testno = \[\"[join [dict get $simulation_map $tb_name] "\",\""]\"\]"
      } elseif {[info exists test_parameters]} {
        #Single testbench or no simulation map exists, assume all defined tests apply to this testbench
        puts $rtlmake_log "    testno = \[\"[join [dict keys $test_parameters] "\",\""]\"\]"
      } else {
        # If we end up here we did not specify a test number and no simulation_map
        # exists and no test_parameters exits.  This is an invalid config and 
        # RTL_make will probably fail somewhere else, but we will log something 
        # anyway.
        puts $rtlmake_log "    testno = \[\"unknown\"\]"
      }
    
      # Run the build command
      if {$build_opt} {
        puts "--------------------------------------------------"
        puts "RTLMAKE: Starting build."
        set success [catch {RTL_sim_lib::build_dependencies $tb_name} err_msg]
        if {$success != 0} {
          puts $rtlmake_log "    build_dependencies = \"error\""
          error $err_msg
        } else {
          puts $rtlmake_log "    build_dependencies = \"success\""
        }
      } else {
        puts $rtlmake_log "    build_dependencies = \"skipped\""
      }

      # Update the contents of the garbage tracking variables.
      set trash_tracker [RTL_sim_lib::update_garbage $trash_tracker]

      # Source the dependencies and compile.
      if {$compile_opt} {
        puts "--------------------------------------------------"
        puts "RTLMAKE: Starting compile."
        set success [catch {source ./vhd_source_list.tcl} err_msg]
        if {$success != 0} {
          puts $rtlmake_log "    compile = \"error\""
          error "RTLMAKE: Loading \"vhd_source_list.tcl\" failed. Got error message: $err_msg"
        }
        # If the user has not specified a compile option default to incremental
        if {[dict exists $RTL_sim_lib::sim_options compile]} {
          set compile_mode [dict get $RTL_sim_lib::sim_options compile]
        } else {
          set compile_mode incr
        }
        # If compile options were specified in test_parameters include them here.
        if {$is_aldec} {
          if {[info exists compile_options]} {
            set success [catch {RTL_sim_lib::compile $src_list $compile_mode $compile_options} err_msg]
          } else {
            set success [catch {RTL_sim_lib::compile $src_list $compile_mode} err_msg]
          }
        }
        if {$is_modelsim} {
          if {[info exists compile_options_modelsim]} {
            set success [catch {RTL_sim_lib::compile $src_list $compile_mode $compile_options_modelsim} err_msg]
          } else {
            set success [catch {RTL_sim_lib::compile $src_list $compile_mode} err_msg]
          }
        }
        if {$success != 0} {
          puts $rtlmake_log "    compile = \"error\""
          error $err_msg
        } else {
          puts $rtlmake_log "    compile = \"success\""
        }
      } else {
        puts $rtlmake_log "    compile = \"skipped\""
      }

      # Update the contents of the garbage tracking variables.
      set trash_tracker [RTL_sim_lib::update_garbage $trash_tracker]

      # Run the simulation command
      if {$simulate_opt} {
        puts "--------------------------------------------------"
        puts "RTLMAKE: Starting simulate."
        # Prepare the list of signals to log. Assume an empty list to begin.
        set wave_list {}
        if {[dict exists $RTL_sim_lib::sim_options loglist] && [info exists wave_lists]} {
          set list_name [lindex [dict get $RTL_sim_lib::sim_options loglist] 1]
          if {[dict exists $wave_lists $list_name]} {
            set wave_list [dict get $wave_lists $list_name]
          } else {
            puts "RTLMAKE: **** WARNING!!!! **** Option 'loglist' specified but no list named '$list_name' exists."
          }
        } elseif {[dict exists $RTL_sim_lib::sim_options loglist]} {
          # loglist was specified but the wave_lists dict was not defined
          puts "RTLMAKE: **** WARNING!!!! **** Option 'loglist' specified but no wave_lists dictionary exists."
        }

        # Package all of the run_tests parameters into a single dictionary.
        # Clear parameters to make sure we start empty.
        set run_test_params {}
        if {[info exists before_sim_commands]} {
          dict set run_test_params before_sim_commands $before_sim_commands
        }

        if {[info exists after_sim_commands]} {
          dict set run_test_params after_sim_commands $after_sim_commands
        }

        if {[info exists test_parameters]} {
          dict set run_test_params test_params $test_parameters
        } else {
          puts $rtlmake_log "    simulate = \"error\""
          error "RTLMAKE: No test parameters defined."
        }
        if {[info exists wave_list]} {
          dict set run_test_params wave_list $wave_list
        }
        if {[llength $RTL_sim_lib::tb_src_list] > 1} {
          dict set run_test_params simulation_map $simulation_map
          dict set run_test_params tb_entity $tb_name
        }
        # If simulation options were specified in test_parameters include them here
        if {$is_aldec} {
          if {[info exists simulate_options]} {
            dict set run_test_params simulate_options $simulate_options
          }
        }
        if {$is_modelsim} {
          if {[info exists simulate_options_modelsim]} {
            dict set run_test_params simulate_options $simulate_options_modelsim
          }
        }
        
        # Resolution option
        if {[info exists resolution_options]} {
          dict set run_test_params resolution_options $resolution_options
        }

        # Run the simulations.
        set success [catch {RTL_sim_lib::run_tests $run_test_params} err_msg]
        if {$success != 0} {
          puts $rtlmake_log "    simulate = \"error\""
          error $err_msg
        } else {
          puts $rtlmake_log "    simulate = \"success\""
        }
      } else {
        puts $rtlmake_log "    simulate = \"skipped\""
      }
    }
  }
  close $rtlmake_log

  # Update the contents of the garbage tracking variables.
  set trash_tracker [RTL_sim_lib::update_garbage $trash_tracker]

  set ran_command_dictionary false
  set printed_warning false

  #Run the verify command
  set rtlmake_log [open "rtl_make.log" "a"]
  puts $rtlmake_log {}
  puts $rtlmake_log "\[verify\]"
  if {$verify_opt} {
    # We allow it to run, if the dictionary exists
    if {[info exists command_dictionary]} {
      set success [catch {RTL_sim_lib::exec_cmd_dictionary $command_dictionary {command dictionary} verify} err_msg]
      if {$success != 0} {
        puts $rtlmake_log "  verify = \"error\""
        error $err_msg
      } else {
        puts $rtlmake_log "  verify = \"success\""
      }
    } else {
      # Warn if verify was specified but no script was given
      puts $rtlmake_log "    verify = \"skipped\""
      set string1 "RTLMAKE: WARNING: Can't execute verification script, 'command_dictionary' or 'after_all_commands'"
      set string2 "not defined in test parameters. Manually review simulation logs for errors."
      puts [concat $string1 $string2]
    }
  } else {
    puts $rtlmake_log "  verify = \"skipped\""
  }
  close $rtlmake_log

  # Report coverage.
  set rtlmake_log [open "rtl_make.log" "a"]
  puts $rtlmake_log {}
  puts $rtlmake_log "\[coverage_info\]"
  if {$coverage_opt} {
    set success [catch {RTL_sim_lib::report_coverage $test_parameters} err_msg]
    if {$success != 0} {
      puts $rtlmake_log "  coverage = \"error\""
      error $err_msg
    } else {
      puts $rtlmake_log "  coverage = \"\"\""
      set cov_results [open "coverage.results" "r"]
      puts -nonewline $rtlmake_log [read $cov_results]
      close $cov_results
      puts $rtlmake_log "\"\"\""
    }
  } else {
    puts $rtlmake_log "  coverage = \"skipped\""
  }
  close $rtlmake_log

  # Run final after_all commands
  set rtlmake_log [open "rtl_make.log" "a"]
  puts $rtlmake_log {}
  puts $rtlmake_log "\[after_all\]"
  if {$after_all_opt} {
    #Run the commands in the after_all dictionary
    set success [catch {RTL_sim_lib::exec_cmd_dictionary $after_all_commands "after_all_commands" after_all} err_msg]
    if {$success != 0} {
      puts $rtlmake_log "  after_all = \"error\""
      error $err_msg
    } else {
      puts $rtlmake_log "  after_all = \"success\""
    }
  } else {
    puts $rtlmake_log "  after_all = \"skipped\""
    if {!$verify_opt} {
      # Didn't run either verify flow, so warn
      set string1 "RTLMAKE: WARNING: Can't execute verification script, 'command_dictionary' or 'after_all_commands'"
      set string2 "not defined in test parameters. Manually review simulation logs for errors."
      puts [concat $string1 $string2]
    }
  }

  # Update the contents of the garbage tracking variables.
  set trash_tracker [RTL_sim_lib::update_garbage $trash_tracker]

  # Clean if necessary. Otherwise, write the list of files to the .garbage file.
  if {$clean_opt} {
    # Clean only files created during previous executions of RTL_make.tcl.
    # Otherwise, clean view-private files as determined by ClearCase.
    if {[dict get $RTL_sim_lib::sim_options clean] == "afterme"} {
      if {[file exists .garbage]} {
        puts "RTLMAKE: Cleaning files created during previous executions of RTL_make.tcl"
        RTL_sim_lib::clean [dict get $trash_tracker garbage]
        RTL_sim_lib::clean .garbage
      } else {
        puts "RTLMAKE: Nothing to clean."
      }
    } else {
      puts "RTLMAKE: Cleaning all view-private files in the sim and tb directories."
      foreach item [RTL_sim_lib::ls_recurse ../sim] {
        if {![file exists $item@@/main/0]} {
          lappend private_list $item
        }
      }
      foreach item [RTL_sim_lib::ls_recurse ../tb] {
        if {![file exists $item@@/main/0]} {
          lappend private_list $item
        }
      }
      RTL_sim_lib::clean $private_list
    }
  } else {
    puts "RTLMAKE: List of files to clean saved to .garbage."
    set fh [open .garbage w]
    puts $fh [dict get $trash_tracker garbage]
    close $fh
  }
}

close $rtlmake_log
puts "RTLMAKE: Complete - Elapsed Time [clock format [expr {[clock seconds] - $timestart}] -format {%H:%M:%S} -timezone :UTC]"

if {$is_aldec_vsimsa || $is_modelsim_vsim} {
  # Ensure the simulator drops back to the shell
  quit
}

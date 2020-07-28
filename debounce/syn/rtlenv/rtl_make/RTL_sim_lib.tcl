#
# Copyright (c) 2014-2018 Schweitzer Engineering Laboratories, Inc.
# SEL Confidential
#
# Brief:
#   TCL library to set up, compile and run RTL test benches.
#
# Details:
#   This file contains a set of procs than can be used to build, compile,
#   set up test benches, simulate, generate reports etc. It abstracts the user
#   from the details of their simulator by making this simulator independent.
#
#   Additionally, some directory utilities are provided to help parse and list
#   directory contents. These are intended to add on TCLs built-in commands,
#   not replace them.
#
# Command Line:
#   One of the procs provided is ::RTL_sim_lib::parse_command_line. This one,
#   allows the user to specify options via the command line rather than hard
#   coding them into the scripts. Some of this options are used inside the
#   procs. All of them are readable via $RTL_sim_lib::sim_options.
#
#   The following options are currently supported:
#
#   help
#     Prints usage help and sets ::RTL_sim_lib::sim_options help.
#
#   run <test bench name>
#     Allows the user to specify a single test bench for which to run build,
#     compile, simulate and report_coverage.
#
#   build <test bench name>
#     It sets ::RTL_sim_lib::sim_options build, and tells
#     ::RTL_sim_lib::build_dependencies which test bench dependencies to to
#     build. <test bench name> must match the name of a folder in the
#     component's tb directory.
#
#   compile
#     It sets ::RTL_sim_lib::sim_options compile.
#     compile options:
#
#       full
#         Deletes the working library and does a re-compilation of all source
#         files
#
#       incr (default)
#         Does not delete the working library. Uses the simulator incremental
#         compilation option, if available.
#
#   simulate
#     It sets ::RTL_sim_lib::sim_options simulate.
#     simulate options:
#
#       logunits { list }
#         or
#       logunits \{ list \}
#         It directs ::RTL_sim_lib::log_signal_wave to log signals for all
#         design hierarchies specified. For example if component 'UUT' instantiates
#         subcomponents 'foo' and 'bar', command "logunits { UUT/foo UUT/bar }"
#         will log all signals within the UUT and both its subcomponents.
#
#         NOTE: The spaces surrounding the curly braces are required.
#
#         NOTE: When running in ModelSim, the backslashes in front of the curly
#         braces are also required.
#
#       loguuts
#         It directs ::RTL_sim_lib::log_signal_wave to log all uut signals and
#         variables.
#
#       logrecursive
#         It directs ::RTL_sim_lib::log_signal_wave to recurse over the
#         hierarchy to log all signals and variables.
#
#       loglist
#         It directs ::RTL_sim_lib::run_tests to provide a list of signals to
#         log to ::RTL_sim_lib::log_signal_wave.
#
#       testbench <test bench name>
#         It specifies which test bench, as specified in <test bench name> to
#         use for simulation. If multiple test benches are present and
#         this option is missing, ::RTL_sim_lib will attempt to automatically
#         resolve the testno requested to a specific testbench. <test bench name>
#         should match the name of a folder in the component's tb directory.
#
#       testno <test identifier>
#         It directs ::RTL_sim_lib to only run the test specified by <test
#         identifier>. <test identifier> can be numeric, alphabetic, or
#         alphanumeric. Underscores are allowed anywhere in the identifier.
#
#   verify
#     It sets ::RTL_sim_lib::sim_options verify.
#
#   report_coverage
#     It sets ::RTL_sim_lib::sim_options report_coverage.
#
#   clean
#     It sets ::RTL_sim_lib::sim_options to only clean files generated during
#     execution of the script. Note, this means that if you create a file
#     during the execution of this script, it may be counted towards the list
#     of files to clean.
#
#   clean_private
#     WARNING!!! This command is only supported on clearcase folders!!!
#     It sets ::RTL_sim_lib::sim_options clean to all view-private, as
#     determined by ClearCase files in the sim, and tb directories.
#
#   runfor
#     Determines a time limit for either a single simulation (if specified) or
#     all simulations to be executed. Accepts up to two inputs as arguments and
#     requires at least one. It is the user's responsibility to ensure that the
#     command line text following 'runfor' is appropriately syntaxed for the
#     'run' command according to the target simulation tool.
#     (e.g 'runfor thehills' is likely not acceptible syntax.)
#
#   There are two primary ways in which this library is intended to be used.
#
# Usage:
#   A) Writing simple scripts that call ::RTL_sim_lib::parse_command_line,
#   ::RTL_sim_lib::compile, ::RTL_sim_lib::run_tests, ::RTL_sim_lib::post_verify, and
#   ::RTL_sim_lib::report_coverage
#
#   B) Writing more complex and involved scripts that call
#   ::RTL_sim_lib::parse_command_line, ::RTL_sim_lib::compile,
#   ::RTL_sim_lib::set_log, ::RTL_sim_lib::initialize_simulation,
#   ::RTL_sim_lib::log_signal_wave, ::RTL_sim_lib::run_simulation,
#   ::RTL_sim_lib::report_coverage, and ::RTL_sim_lib::report_coverage
#
# Remarks:
#   - Supports Active-HDL 10.1 and Active-HDL 10.2
#
#   - Supports Modelsim 10.6c
#
#   - This script relies on simulations terminating themselves. This can be
#     achieved in multiple ways, for example:
#       Stopping the simulation clocks
#       Using ieee std.env.stop
#       Using 'runfor' command with set simulation time limit
#

package require Tcl 8.5

# Include the MD5 library, if not already included.  This IF avoids this message:
#   Error: conflicting versions provided for package "md5": 2.0.7, then 1.4.4
if {[catch {md5::md5 "If MD5 is not already installed:"}]}  {
  source [file dirname [info script]]/tcllib/modules/md5/md5.tcl
}

# Default working library name is "work".  This global variable can be
# overridden by an external script such as test_parameters.tcl.
set working_library_name work
set working_library_folder [pwd]/work

# Create the namespace.
namespace eval ::RTL_sim_lib {
  # Export public commands.
  namespace export \
    parse_command_line \
    build_dependencies \
    set_log \
    compile \
    initialize_simulation \
    run_simulation \
    run_timed_simulation \
    run_tests \
    log_signal_wave \
    post_verify \
    report_coverage \
    ls_recurse \
    lsubtract \
    update_garbage \
    clean

  # This is a set of namespace constant variables used across procs. TCL does
  # not have the concept of const, thus, it is up to the developers to make
  # sure this is maintained.
  # Set up this script's path and name.
  variable my_name [file join [file dirname [info script]] RTL_sim_lib.tcl]
  # Set up some namespace variables to identify the simulation environment.
  variable is_aldec        [expr [info exists aldec]]
  variable is_aldec_vsimsa [expr $is_aldec && [info exists BatchMode]]
  variable is_aldec_gui    [expr $is_aldec && !$is_aldec_vsimsa]
  variable is_modelsim     [info exists vsimPriv]
  # If users follow the rules, this gives us the component's sim folder.
  variable component_path  [regsub {/sim$} [pwd] ""]
  # Auto-extracted list of test benches.
  variable tb_src_list [glob -directory "${component_path}/tb" -type d *]

  # Set of simulation options as dynamically specified by the user. Create an
  # entry so that it exists!
  variable sim_options [dict create created 1]

  variable is_clearcase [expr ![catch {exec cleartool catcs}]]
}


#
# Brief:
#   Parses the command line for simulation option arguments.
#
# Details:
#   Some command lines are used in some of the namespace procs. Others, simply
#   create and set an entry in the Simulation Options dictionary
#   ::RTL_sim_lib::sim_options. This dictionary is accessible from sourcing
#   scripts via $::RTL_sim_lib::sim_options.
#
#   Refer to the header of this file for a list of supported options.
#
# Usage:
#   RTL_sim_lib::parse_command_line
#
# Remarks:
#   It consumes $argv (i.e. it empties it) to set the $sim_options
#     dictionary.
#   loguuts and logrecursive are all mutually exclusive. However, this
#   procedure will parse them and set the options.
#
proc ::RTL_sim_lib::parse_command_line {} {
  global argc
  variable is_aldec
  variable is_modelsim
  variable is_clearcase
  variable my_name
  upvar ::RTL_sim_lib::sim_options sim_options

  # Modelsim passes argc to other scripts, but does not pass argv!?. Instead,
  # the arguments that would be in argv are pass in variables $1..$9. Thus,
  # recover argv and argc and set it. This overwrites global argv in Modelsim,
  # this is OK for now, but we should take it into consideration. I went that
  # route so that it would all be transparent to the user.
  if {$is_modelsim} {
    global 1 2 3 4 5 6 7 8 9
    set argv {}
    set myargc $argc
    while {$argc > 0} {
      lappend argv $1
      shift
    }
    set argc $myargc
  } else {
    global argv
  }

  puts "RTLSIMLIB: Parsing command line arguments if they exist..."
  if {($argc > 0)} {
    puts "RTLSIMLIB: Command line arguements are: $argv."

    # The 'runfor' command requires at least one additional input and can accept
    # up to two additional inputs. For example, both 'runfor 10ns' and
    # 'runfor 10 ns' are acceptible. Additionally, the the following code allows
    # for 'run' command tags, too, like 'run -all'. (although I do not know what
    # use case tags might have using RTL_make) It is the user's responsibility
    # to ensure the text that follows 'runfor' is a viable command for 'run'
    # within the target tool being used.
    set argind 1
    set runfor_param_index1 0
    set runfor_param_index2 0
    set gotrunfor_param_index1 0
    set gotrunfor_param_index2 0

    # Loop through all arguments and find the inputs for 'runfor'
    foreach arg $argv {

      if {[string equal -nocase $arg "runfor"]} {
        # found runfor, now need to extract command options

        if {[expr $argind + 2] <= $argc} {
          # At least 2 more args, next two could be for the runfor command
          set runfor_param_index1 [expr $argind + 1]
          set runfor_param_index2 [expr $argind + 2]
        } elseif {[expr $argind + 1] == $argc} {
          # Only one more arg, next one could be for the runfor command
          set runfor_param_index1 [expr $argind + 1]
        } else {
          # could not find valid arg
          error "RTLSIMLIB: Command 'runfor' needs input parameters."
        }
      }

      if {$argind == $runfor_param_index1} {
        # error if this arg is a known command to RTL_make
        if {[string equal -nocase $arg "help"] || [string equal -nocase $arg "run"] || [string equal -nocase $arg "build"] || [string equal -nocase $arg "compile"] || [string equal -nocase $arg "simulate"] || [string equal -nocase $arg "logunits"] || [string equal -nocase $arg "loguuts"] || [string equal -nocase $arg "logrecursive"] || [string equal -nocase $arg "loglist"] || [string equal -nocase $arg "testbench"] || [string equal -nocase $arg "testno"] || [string equal -nocase $arg "verify"] || [string equal -nocase $arg "report_coverage"] || [string equal -nocase $arg "clean_private"] || [string equal -nocase $arg "clean"]} {
          error "RTLSIMLIB: Command 'runfor' needs input parameters."
        } else {
          set gotrunfor_param_index1 1
          set input1 $arg
        }
      }

      if {$argind == $runfor_param_index2 && $gotrunfor_param_index1} {
        # error if this arg is a known command to RTL_make
        if {![string equal -nocase $arg "help"] && ![string equal -nocase $arg "run"] && ![string equal -nocase $arg "build"] && ![string equal -nocase $arg "compile"] && ![string equal -nocase $arg "simulate"] && ![string equal -nocase $arg "logunits"] && ![string equal -nocase $arg "loguuts"] && ![string equal -nocase $arg "logrecursive"] && ![string equal -nocase $arg "loglist"] && ![string equal -nocase $arg "testbench"] && ![string equal -nocase $arg "testno"] && ![string equal -nocase $arg "verify"] && ![string equal -nocase $arg "report_coverage"] && ![string equal -nocase $arg "clean_private"] && ![string equal -nocase $arg "clean"]} {
          set gotrunfor_param_index2 1
          set input2 $arg
          break
        }
      }

      incr argind
    }

    # Now put the commands together and store them appropriately
    if {$gotrunfor_param_index1} {
      set rslt $input1
      if {$gotrunfor_param_index2} {
        append rslt " " $input2
      }
      puts "RTLSIMLIB: Found 'runfor $rslt' as a set of command line arguments."
      dict set sim_options runfor $rslt
    }

    # Look for all other arguments
    set argind 1
    set ignore_next 0
    set ignore_list 0
    set got_compile 0
    foreach arg $argv {

      # Ignore indices that correspond to various argument parameters
      # Those indices are as follows:
      #  a) Ignore the indice immediately following 'run', 'build', 'loglist', 'testbench', and 'testno' (Indicated
      #     by $ignore_next != 0)
      #  b) Ignore the list specified following 'logunits' (Indicated by $ignore_list != 0)
      #  c) Ignore the indice immediately following 'runfor' and optionally the one after that (indicated by
      #     $argind == $runfor_param_index1 || $argind == $runfor_param_index2)
      if {$argind != $runfor_param_index1 && $argind != $runfor_param_index2 && $ignore_next == 0 && $ignore_list == 0} {

        if {[string equal -nocase $arg "help"]} {
          dict set sim_options help 1
          # Read this script and print the comments as help.
          puts "#\t\t-----------------------------------------------------------"
          puts "#\t\t   RTLSIMLIB: RTL_sim_lib.tcl help:"
          puts "#\t\t-----------------------------------------------------------"
          set fh [open $my_name r]
          while {[gets $fh line]} {
            puts "$line"
          }
          close $fh

        } elseif {[string equal -nocase $arg "run"]} {
          if {[regexp -nocase -- {run [./\w]+} $argv testbench]} {
            dict set sim_options build [lindex $testbench 1]
            dict set sim_options compile incr
            dict set sim_options simulate 1
            dict set sim_options testbench [lindex $testbench 1]
            dict set sim_options report_coverage 1
            set ignore_next 1
          }

        } elseif {[string equal -nocase $arg "build"]} {
          if {[regexp -nocase -- {build [./\w]+} $argv testbench]} {
            dict set sim_options build [lindex $testbench 1]
            puts "RTLSIMLIB: Found 'build' as a command line argument."
            set ignore_next 1
          } elseif {[regexp -nocase -- {build} $argv testbench]} {
            error "RTLSIMLIB: 'build' needs the name of the test bench as a parameter."
          }

        } elseif {[string equal -nocase $arg "compile"]} {
          dict set sim_options compile "incr"
          puts "RTLSIMLIB: Found 'compile' as a command line argument."
          puts "RTLSIMLIB: Compile mode defaults to 'incr'."
          set got_compile 1

        } elseif {[string equal -nocase $arg "verify"]} {
          dict set sim_options verify 1
          puts "RTLSIMLIB: Found 'verify' as a command line argument."

        } elseif {[string equal -nocase $arg "report_coverage"]} {
          dict set sim_options report_coverage 1
          puts "RTLSIMLIB: Found 'report_coverage' as a command line argument."

        } elseif {[string equal -nocase $arg "clean_private"]} {
          puts "RTLSIMLIB: Found 'clean_private' as a command line argument."
          if {!$is_clearcase} {
            error "RTLSIMLIB: Could not confirm that the current working directory is within a ClearCase-mapped drive. Command 'clean_private' aborted!"
          } else {
            dict set sim_options clean private
          }

        } elseif {[string equal -nocase $arg "clean"]} {
          dict set sim_options clean afterme
          puts "RTLSIMLIB: Found 'clean' as a command line argument."

        } elseif {[string equal -nocase $arg "runfor"]} {
          # Do nothing here, the runfor command was processed earlier

        } elseif {[string equal -nocase $arg "full"]} {
          if {$got_compile} {
            dict set sim_options compile "full"
            puts "RTLSIMLIB: Setting compile mode to 'full'."
          } else {
            error "RTLSIMLIB: Missing command 'compile'?"
          }

        } elseif {[string equal -nocase $arg "incr"]} {
          # Just need to check that the 'compile' command precedes "incr"
          # Compile mode defaults to incr
          if {!$got_compile} {
            error "RTLSIMLIB: Missing command 'compile'?"
          }

        } elseif {[string equal -nocase $arg "simulate"]} {
          if {[string equal -nocase $arg "simulate"]} {
            dict set sim_options simulate 1
            puts "RTLSIMLIB: Found 'simulate' as a command line argument."
          }

        } elseif {[string equal -nocase $arg "logunits"]} {
          if {[regexp -nocase -- {(?:logunits) \\{([./ \w]+)\\}} $argv option uut_list]} {
            dict set sim_options logunits $uut_list
            puts "RTLSIMLIB: Found 'logunits' as an option for 'simulate'."
            set ignore_list 1
          } else {
            error "RTLSIMLIB: 'logunits' needs a list of unit hierarchies as a parameter."
          }

        } elseif {[string equal -nocase $arg "loguuts"]} {
          dict set sim_options loguuts 1
          puts "RTLSIMLIB: Found 'loguuts' as an option for 'simulate'."

        } elseif {[string equal -nocase $arg "logrecursive"]} {
          dict set sim_options logrecursive 1
          puts "RTLSIMLIB: Found 'logrecursive' as an option for 'simulate'."

        } elseif {[string equal -nocase $arg "loglist"]} {
          if {[regexp -nocase -- {loglist [./\w]+} $argv list_name]} {
            dict set sim_options loglist $list_name
            puts "RTLSIMLIB: Found 'loglist' as an option for 'simulate'."
            set ignore_next 1
          }

        } elseif {[string equal -nocase $arg "testbench"]} {
          if {[regexp -nocase -- {testbench [./\w]+} $argv testbench]} {
            dict set sim_options testbench [lindex $testbench 1]
            puts "RTLSIMLIB: Found 'testbench' as an option for 'simulate'."
            set ignore_next 1
          } elseif {[regexp -nocase -- {testbench} $argv testbench]} {
            error "RTLSIMLIB: 'testbench' needs the name of the test bench as a parameter."
          }

        } elseif {[string equal -nocase $arg "testno"]} {
          if {[regexp -nocase -- {testno [./\w]+} $argv option]} {
            dict set sim_options testno [lindex $option 1]
            puts "RTLSIMLIB: Found 'testno' as an option for 'simulate'."
            set ignore_next 1
          }

        } elseif {[string equal -nocase $arg "before_all"]} {
          dict set sim_options before_all 1
          puts "RTLSIMLIB: Found 'before_all' as a command line argument."

        } elseif {[string equal -nocase $arg "after_all"]} {
          dict set sim_options after_all 1
          puts "RTLSIMLIB: Found 'after_all' as a command line argument."

        } else {
          error "RTLSIMLIB: Found unknown command line argument '$arg'."
        }

      } elseif {$ignore_next != 0} {
        # This arg index is the parameter of the previous arg. Ignore it.
        set ignore_next 0

      } elseif {$ignore_list != 0} {
        # The current argument must be part of a list included for the 'logunits' command
        if {[string equal -nocase $arg "\}"]} {
          # found end-curly-brace to the logunits list, next arg should be valid
          set ignore_list 0
        }
      }

      incr argind
    }
  }
}

#
# Brief:
#   Build the dependencies for the component's simulation.
#
# Parameter [Input]: testbench
#   Name of the testbench for which to build the dependencies.
#
# Details:
#   If the component has a single test bench its dependencies are built. If
#   there are multiple test benches, the one specified by $sim_options build is
#   used. Otherwise, the first one found is used.
#
# Usage:
#   RTL_sim_lib::build my_component_tb
#
proc ::RTL_sim_lib::build_dependencies {{testbench {}}} {
  variable sim_options
  variable component_path
  variable tb_src_list
  variable my_name

  set tb_path [file join $component_path tb]

  set timestart [clock seconds]

  # get path of build_rtl.pl
  # Find my path because a few of our checks are relative to my location.
  set my_path [file dirname $my_name]
  # First check the relative path for the build_rtl and rtl_make repositories
  # cloned down side by side.  This verifies the folder we were in was rtl_make.
  # This check should support RTLenv and Repo flows when using the two separate
  # repositories.
  if {[file exists "$my_path/../rtl_make/../build_rtl/build_rtl.pl"]} {
    set build_rtl_path [file normalize "$my_path/../build_rtl/build_rtl.pl"]
  # Support for the old combined "tools" repository was removed as this version
  # of code should never appear in that specific folder structure.
  # Next check for clearcase absolute path which supports the clearcase flow.
  } elseif {[file exists /tools/bin/build_rtl.pl]} {
    set build_rtl_path [file normalize "/tools/bin/build_rtl.pl"]
  # if we don't find build_rtl we error out.
  } else {
    set my_error "RTLSIMLIB: Cannot find build_rtl.pl.  Tried:"
    append my_error "\n     " [file normalize "$my_path/../build_rtl/build_rtl.pl"]
    append my_error "\n     " [file normalize "/tools/bin/build_rtl.pl"]
    error $my_error
  }
  puts "RTLSIMLIB: Found build_rtl at: $build_rtl_path"

  # Select a testbench to build, using a user-provided option if it exists.
  if {[dict exists $sim_options build]} {
    set tb_path [file join $tb_path [dict get $sim_options build]]

  } elseif {$testbench != {}} {
    set tb_path [file join $tb_path $testbench]

  } elseif {[llength $tb_src_list] > 1} {
    error "RTLSIMLIB: Multiple test bench entities exist. Please specify which one to build."
  } else {
    # Build the only testbench that exists.
    set tb_path $tb_src_list
  }

  # Verify the testbench directory and testbench build script exist, then run
  # the RTL build tool. Verifying that a valid directory and build script exist
  # allows RTL_sim_lib to provide meaningful error messages and fail in a
  # graceful way in more situations.
  puts [concat "RTLSIMLIB: Attempting to build test bench" [file tail $tb_path]]
  if [file exists $tb_path] {
    if [file exists [file join $tb_path "syn" "build.pl"]] {
      set success [catch {exec perl $build_rtl_path $tb_path}]
    } else {
      error [concat "RTLSIMLIB: The specified testbench \"" [file tail $tb_path] "\" build.pl script does not exist."]
    }
  } else {
    error [concat "RTLSIMLIB: The specified testbench directory \"" [file tail $tb_path] "\" does not exist."]
  }

  if {$success != 0} {
    if [file exists [file join $tb_path "reports" "build_rtl.log"]] {
      set fh [open [file join $tb_path "reports" "build_rtl.log"]]
      puts [read $fh]
      close $fh
      error "Subroutine \"build_rtl.pl\" exited abnormally. Refer to <UUT>/tb/<UUT TB Name>/reports/build_rtl.log for error details (shown above)."
    } else {
      error "Subroutine \"build_rtl.pl\" exited abnormally and build_rtl.log does not exist.  Verify that your computer has Perl installed."
    }
  }

  puts "RTLSIMLIB: Build Complete - Elapsed Time [clock format \
    [expr {[clock seconds] - $timestart}] -format {%H:%M:%S} -timezone :UTC]\n\n"

}


#
# Brief:
#   Sets up the name of the transcript log file.
#
# Parameter [Input]: log_name
#   Name of the log file without extension.
#
# Parameter [Input]: log_path (optional)
#   Location in which to place the log file.
#
# Usage:
#   RTL_sim_lib::set_log compilation_1 <INSERT PATH>/my_component/sim
#
proc ::RTL_sim_lib::set_log {log_name {log_path .}} {
  variable is_aldec
  variable is_modelsim

  # Set up the file name.
  set log_file [file join $log_path $log_name.log]

  # Do some FS check. Always create a new file never append.
  if {$is_aldec} {
    if {[file exists $log_file]} {
      file delete $log_file
    }
    transcript to $log_file
    puts "RTLSIMLIB: Setting log file to $log_file"
  }
  if {$is_modelsim} {
    if {[file exists $log_file]} {
      file delete $log_file
    }
    transcript file $log_file
    puts "RTLSIMLIB: Setting log file to $log_file"
  }
}


#
# Brief:
#   Executes per-sim scripts.
#
# Parameter [Input]:
#   Test number/value key (testno arg when calling from cmd line)
#   Dictionary with (potentially) [before | after]_sim_commands  in it
#   Before (not after) sim (1), or after sim (0)
# Usage:
#    RTL_sim_lib::per_sim_cmd $test_no $command_dictionary $before_not_after
#
# Remarks:
#   This proc looks for a) before_sim_commands/after_sim_commands exists and
#   b) the given test_no is in the before_sim_commands dictionary.
#   A given test may have one entry - only one script will be run per testno.
#
proc ::RTL_sim_lib::per_sim_cmd {test_no command_dictionary before_not_after} {

  if {[dict exists $command_dictionary before_sim_commands] && $before_not_after == 1} {
    set temp_dict [dict get $command_dictionary before_sim_commands]
  } elseif {[dict exists $command_dictionary after_sim_commands] && $before_not_after == 0} {
    set temp_dict [dict get $command_dictionary after_sim_commands]
  } else {
    #No before/after sims specified
    if {$before_not_after} {
      puts "RTLSIMLIB: No before_sim_command script specified for testno $test_no"
    } else {
      puts "RTLSIMLIB: No after_sim_command script specified for testno $test_no"
    }
    # Exit, as there's nothing for us to do if the dict doesn't exist
    return 0
  }

  # If here, then the dictionary at least exists
  if {[dict exists $temp_dict $test_no]} {
    set pre_sim_hook [dict get $temp_dict $test_no]

    # The testno has a pre-sim hook; run it
    if {$before_not_after} {
      set file_name "before_sim_$test_no.log"
    } else {
      set file_name "after_sim_$test_no.log"
    }

    if {[file exists $file_name]} {
      file delete $file_name
    }

    # Get the current command to execute
    set script_command $pre_sim_hook

    # Execute the command, send to log file
    if {$before_not_after} {
      puts "RTLSIMLIB: Executing before_sim $test_no '$script_command'.\n"
    } else {
      puts "RTLSIMLIB: Executing after_sim $test_no '$script_command'.\n"
    }

    # Do the command, Send both STD_ERR and STD_OUT to the log file
    set success [catch {exec {*}$script_command >>& $file_name}]

    # Print the log file to the console
    set fh [open $file_name r]
    puts [read $fh]
    close $fh
    if {$success != 0} {
      error "Subroutine '$script_command' exited abnormally. See '$file_name' for error details (shown above)."
    } else {
      puts "RTLSIMLIB: '$script_command' complete. See console and '$file_name' for results.\n\n"
    }
  } else {
    #No before/after sims specified for this testno in particular
    if {$before_not_after} {
      puts "RTLSIMLIB: No before_sim_command script specified for testno $test_no"
    } else {
      puts "RTLSIMLIB: No after_sim_command script specified for testno $test_no"
    }
  }
}


#
# Brief:
#   Compiles all the simulation dependencies.
#
# Parameter [Input]: src_list
#   TCL list containing all the source files.
#
# Paramter [Input]: compile_mode
#   String specifying the compilation mode:
#     "incr" - Incremental compilation, if available in simulator
#     "full" - Delete the default working library and re-compile everything
#
# Parameter [Input]: compiler_options (optional)
#   String of options to apply to the basic compilation command or a dictionary
#   of key-value pairs specifying additional options for specific source files.
#   The exception to the rule is passing -2008 which overrides the default -93.
#
# Usage:
#   RTL_sim_lib::compile $src_list incr "-ieee_nowarn"
#
# Remarks:
#   By default, the basic compilation command for source and test bench files
#   are respectively:
#   "vcom -explicit -93   -work work"
#   "vcom -explicit -2008 -work work"
#
# All files specified in $tb_src as well as all files in
# /components/rtl/tb are compiled using the VHDL-2008 rules.
#
# The compilation log is named after the last source file in the source list. In
# VHDL, this will always be the top-level VHDL entity.
#
proc ::RTL_sim_lib::compile {src_list compile_mode {compiler_options {}}} {
  global working_library_name
  global working_library_folder
  variable is_aldec
  variable is_aldec_gui
  variable is_modelsim
  variable is_clearcase
  variable component_path

  set timestart [clock seconds]

  # For Modelsim Builds, there is a limit in place
  set file_limit 20

  # Active-HDL requires a design to create a work library. Name it to match our library:
  if {$is_aldec_gui} {
    if {![file exist $working_library_folder/my_design]} { ;# No Aldec project: CREATE it
      puts "RTLSIMLIB: Creating new design..."
      set pwd [pwd]
      design create -a my_design $working_library_folder
      design open -a $working_library_folder/my_design
      cd $pwd
    } else {  ;# project already created, just OPEN it, if not already open:
      upvar 1 dsnname dsnname
      if {[llength $dsnname] == 0} {  ;# if project not already open:
        puts "RTLSIMLIB: Opening design..."
        set pwd [pwd]
        design open -a $working_library_folder/my_design
        cd $pwd
      }
    }
  }

  # Set variables to identify the src, syn, and tb folders.
  set src_path  [file join $component_path src]
  set syn_path  [file join $component_path syn]
  set tb_path   [file join $component_path tb]

  # Create a list containing the names of the UUTs, and another one containing
  # the names of the entities of all TB sources.
  set uut_names {}
  foreach src [glob -directory $src_path *.vhd] {
    lappend uut_names [file rootname [lindex [file split $src] end]]
  }

  set tb_names {}
  foreach src [glob -directory $tb_path *] {
    lappend tb_names [file rootname [lindex [file split $src] end]]
  }

  # If full compilation is requested, delete the default working library.
  if {$compile_mode eq "full"} {
    if {[file exists $working_library_name]} {
      file delete -force $working_library_name
    }
  }

  # Set up the compilation log.
  # Named after the last source in the source list
  set log_name "compilation_[lindex [file split [lindex $src_list end]] end-2]"
      RTL_sim_lib::set_log $log_name

  # Set up a base VHDL compilation command.
  set b_cmd "vcom -explicit -93  "

  # Apply options to the command in Aldec.
  if {$is_aldec} {
    if {$is_clearcase} {
      # The Aldec tool does not like having its working folder located in
      # clearcase ux dynamic views.  To avoid this situation we move the working
      # library to your systems temporary folder.  The following code to create
      # a temporary folder was copied from http://wiki.tcl.tk/772
      if {[file exists "/tmp"]} {set working_library_folder "/tmp"}
      catch {set working_library_folder $::env(TRASH_FOLDER)}
      catch {set working_library_folder $::env(TMP)}
      catch {set working_library_folder $::env(TEMP)}
      append working_library_folder [join [list "/RTLMake/" [::md5::md5 [pwd]]] ""]
      puts "RTLSIMLIB: The working_library_folder is: $working_library_folder"
    }
    if {$compile_mode eq "full" && [file exists $working_library_folder]} {
      file delete -force $working_library_folder
    }
    vlib $working_library_name $working_library_folder/$working_library_name.lib
  }

  # Apply options to the command in Active-HDL.
  if {$is_aldec_gui} {
    append b_cmd " -dbg"
  }

  # Apply options to the command in ModelSim
  if {$is_modelsim} {
    vlib $working_library_name

    # ModelSim message 1309 is an error that occurs from using aliases in test
    # benches. The error is usually the result of the aliased signal being
    # located at a lower level in the hierarchy than the alias itself, which
    # means that the signal hasn't been elaborated at compile time, but will be
    # detected at run time.
    append b_cmd " -suppress 1309"
  }

  # Only append the options if they exist as a single string.
  if {[llength $compiler_options] == 1} {
    append b_cmd " $compiler_options"
  }

  # List all common testbench components. Needed to identify that they should
  # be compiled with VHDL 2008 in Git.
  set testbench_components {
      apb_master
      apb_slave
      coldfire_flexbus_master
      eth_master
      eth_ping_return
      eth_slave
      eth_smi_slave
      eth_logic_analyzer
      gmii_master
      gmii_recorder
      gmii_slave
      i2c_slave
      irb_master
      irb_master_be
      linked_list
      lpc_master
      mac_master
      mac_recorder
      mac_slave
      mii_sniffer
      opb_master
      pcapng_processing
      powerpc_ext_master
      print_fnc
      random_number_gen
      rgmii_master
      rgmii_recorder
      rgmii_slave
      rmii_master
      rmii_recorder
      rmii_slave
      saif_master
      saif_monitor
      saif_recorder
      saif_slave
      seirq_master
      sharc_asynch_master
      spi_slave
      start_done_master
      start_done_slave
      tb_tcon
      tb_tcon_clocker
      tb_tcon_gpio
      tb_tcon_irb_master
      tb_tcon_saif
      tb_tcon_start_done
      text_processing
      waves_monitor
  }

  # Compile all sources one at a time applying modifications if required.
  foreach src $src_list {
    # Look through the compiler_options dictionary for this source.
    # This is needed because the filename might have a partial path to prevent
    # two files with the same name at different hierarchy from colliding
    set target_key 0;
    foreach item [dict keys $compiler_options] {
      if {[string first $item $src] > -1} {
        set target_key $item
      }
    }

    # Check for Verilog or System Verilog Files and change to vlog instead of vcom.
    if {[regexp -nocase {(\.sv|\.v|\.vo)$} $src]} {
      puts "RTLSIMLIB: Found Verilog/System Verilog File: $src"
      set src_cmd "vlog "

      # Look for compiler options for this source.
      if {$target_key != 0} {
        regexp -nocase {\-work ([^ ]+)} [dict get $compiler_options $target_key] custom_work_lib libname
        # Specified a different libary name, so add that library instead of the default working library
        if {[string match "*-work*" [dict get $compiler_options $target_key]]} {
          append src_cmd " [dict get $compiler_options $target_key]"
          # Also add the new library to the project, in case it doesn't exist
          # Create a library
          vlib $libname
        # No special library specified, so just compile into the default working library
        } else {
          append src_cmd " -work $working_library_name [dict get $compiler_options $target_key]"
        }
      # No compiler options specified, so just compile into the default working library
      } else {
        append src_cmd " -work $working_library_name"
      }
    } else {
      # Modified compilation command.
      set src_cmd $b_cmd

      if {$target_key != 0} {
        regexp -nocase {\-work ([^ ]+)} [dict get $compiler_options $target_key] custom_work_lib libname
        # Specified a different libary name, so add that library instead of the default working library
        if {[string match "*-work*" [dict get $compiler_options $target_key]]} {
          append src_cmd " [dict get $compiler_options $target_key]"
          # Also add the new library to the project, in case it doesn't exist
          vlib $libname
        # No special library specified, so just compile into the default working library
          } else {
          append src_cmd " -work $working_library_name [dict get $compiler_options $target_key]"
        }
      # No compiler options specified, so just compile into the default working library
      } else {
        append src_cmd " -work $working_library_name"
      }

      # It is part of the UUT if it is found in ./src.
      if {[regexp -nocase $src_path $src]} {
        if {$is_aldec} {
          # Collect expression coverage statistics if the source is identified as
          # part of the UUT. The statistics collected are:
          # s - statement, b - branch, e - expression (conditional),
          # p - path, a - assertion.
          append src_cmd " -coverage sbecpa -coverage_options assert+implicit"
        }
        if {$is_modelsim} {
          # Collect expression coverage statistics if the source is identified as
          # part of the UUT. The statistics collected are:
          # s - statement, b - branch, e - expression, c - conditional
          append src_cmd " +cover=sbec"
        }
        puts "RTLSIMLIB: Collecting coverage statistics for $src"
      }

      # The following section is intended to identify components whose source
      # file is copied into a directory somewhere within the component's main
      # directory as a result of the the build process.

      # One example of a component that this rule applies to is
      # 'components/rtl/cal_deskew' which requires its instance have a <tag>
      # attribute be replaced with a specific instance identifier. In this
      # case, a cal_deskew_sim.vhd is generated and placed in directory
      # 'components/rtl/cal_deskew/tb/cal_deskew_tb/syn/'.

      # Sources in which the component's name appears at the beginning of the
      # file name will be included in the coverage report if that source can
      # be found within a directory that is included in a the component's main
      # directory. For instance, if the component's name is 'component', then
      # source 'component/syn/component_foo.vhd' will be included. However,
      # source 'component/syn/foo_component.vhd' will not.
      set src_name [file rootname [lindex [file split $src] end]]
      if {[lsearch $tb_names $src_name] == -1} {
        foreach uut_src $uut_names {
          # Only count files that exist within a directory inside the tb or
          # syn directories and contain the component name at the beginning
          # of the file name. Also, exclude any file within the rtlenv folder.
          if {[regexp -nocase ^$uut_src $src_name]} {
            if {[regexp -nocase $tb_path $src] || ([regexp -nocase $syn_path $src] && ![regexp -nocase $syn_path/rtlenv $src])} {
              if {$is_aldec} {
                append src_cmd " -coverage sbecpa -coverage_options assert+implicit"
              }
              if {$is_modelsim} {
                append src_cmd " +cover=sbec"
              }
              puts "RTLSIMLIB: Collecting coverage statistics for $src"
            }
          }
        }
      }

      # Define the folder the source file is in and the name of the component
      # by parsing the file's path.
      set dir_name [lindex [file split $src] end-1]
      set comp_name [lindex [file split $src] end-2]

      # Compile test bench sources using VHDL-2008 for
      # 1) Components with "tb_" prefix in the name, or
      # 2) Common RTL TB components, or
      # 3) TB sources in the component's tb directory.
      if {
        [regexp -nocase {^tb_} $comp_name] ||
        ($dir_name == "src" && $comp_name in $testbench_components) ||
        [regexp -nocase $tb_path/.+/src $src]
      } {
        puts "RTLSIMLIB: Identified [lindex [file split $src] end] as a source file for a testbench component. Compiling in VHDL-2008"
        # Clear the -93 flag and set -2008.
        regsub -all {\-93  } $src_cmd "-2008" src_cmd
      }
    }

    # To speed up compilation time, collect in a list files that have the same
    # compilation command, then run a single command for the list.
    # Keep track of the command for the last list of files. If the command for
    # the new file matches the previous command, add the file to the list.
    # Otherwise, run the command for the current list and start a new list.
    if {[info exists list_src_cmd] && $list_src_cmd eq $src_cmd} {
      lappend src_compile_list $src
    } else {
      # Execute the simulation command before starting a new one.
      if {[info exists list_src_cmd]} {

        if {$is_modelsim} {
          set list_src_cmd_list {}
          set start 0
          set end [expr {$file_limit-1}]

          while {$start < llength($src_compile_list)} {
            lappend list_src_cmd_list [lrange $src_compile_list $start $end]

            incr start $file_limit
            incr end $file_limit
          }

          foreach {src_list} $list_src_cmd_list {
            puts "RTLSIMLIB: Compiler command: $list_src_cmd"
            eval $list_src_cmd $src_list
          }
        } else {
          # Aldec Active HDL
          puts "RTLSIMLIB: Compiler command: $list_src_cmd"
          eval $list_src_cmd $src_compile_list
        }

      }
      # Start new command and a new file list.
      set src_compile_list $src
      set list_src_cmd $src_cmd
    }
  }

  # Run the last command since it is pending.
  if {$is_modelsim} {
    # Extract the list_src_cmd list into a list of lists (20 sources per list)
    set list_src_cmd_list {}
    set start 0
    set end [expr {$file_limit-1}]

    while {$start < llength($src_compile_list)} {
      lappend list_src_cmd_list [lrange $src_compile_list $start $end]

      incr start $file_limit
      incr end $file_limit
    }

    foreach {src_list} $list_src_cmd_list {
      puts "RTLSIMLIB: Compiler command: $list_src_cmd"
      eval $list_src_cmd $src_list
    }
  } else {
    # Aldec Active HDL
    puts "RTLSIMLIB: Compiler command: $list_src_cmd"
    eval $list_src_cmd $src_compile_list
  }


  puts "RTLSIMLIB: Compilation Complete - Elapsed Time [clock format \
    [expr {[clock seconds] - $timestart}] -format {%H:%M:%S} -timezone :UTC]\n\n"
}

#
# Brief:
#   Initializes the simulation.
#
# Parameter [Input]: testno
#   Test for which to initialize the simulation.
#
# Parameter [Input]: tb_entity
#   String representing the name of the testbench entity. Simulation Top Level.
#
# Parameter [Input]: sim_parameters
#   Simulation Parameters dictionary for test identifier "testno".
#
# Parameter [Input]: sim_resolution
#   Required parameter. Define simulation time resolution.
#
# Parameter [Input]: tb_options
#   Optional parameter. Additional options for the simulation command.
#
# Usage:
#   RTL_sim_lib::initialize_simulation 1 my_component_tb $generic_value_pairs
#
proc ::RTL_sim_lib::initialize_simulation {testno tb_entity sim_parameters sim_resolution {tb_options {}}} {
  global working_library_name
  variable is_aldec
  variable is_aldec_gui
  variable is_modelsim

  # The tb_options parameter is optional, but if it is not specified it defaults
  # to an empty string so we can always use it in the following expression:
  set init_sim_cmd "vsim $tb_entity -lib $working_library_name $tb_options"

  if {$is_aldec} {
    append init_sim_cmd " -acdb -cc_hierarchy -exc control"
    append init_sim_cmd " -asdb test_$testno.asdb"
    if {$is_aldec_gui} {
        # Enable Show Event Source feature in Aldec GUI
        append init_sim_cmd " -ses"
    }
    append init_sim_cmd " -t "
    append init_sim_cmd $sim_resolution
  }

  if {$is_modelsim} {
      append init_sim_cmd " -t "
      append init_sim_cmd $sim_resolution
      append init_sim_cmd " -wlf test_$testno.wlf -autoexclusionsdisable=assertions -coverage"
    }
  

  # Set up the generics. Override default generic values.
  dict for {generic value} $sim_parameters {
    append init_sim_cmd " -g${generic}=${value}"
  }
  puts "RTLSIMLIB: Simulator command: $init_sim_cmd"
  eval $init_sim_cmd
}


#
# Brief:
#   Runs a simulation.
#
# Parameter [Input]: testno
#   Test for which to run the simulation.
#
proc ::RTL_sim_lib::run_simulation {testno} {
  variable is_aldec
  variable is_modelsim

  if {$is_aldec} {
    run
    acdb save -file coverage/test_$testno.acdb
    endsim
  }
  if {$is_modelsim} {
    run -all
    if {![file exists ./coverage]} {
      file mkdir ./coverage
    }
    coverage save coverage/test_$testno.ucdb
  }
}

#
# Brief:
#   Runs a time-limited simulation.
#
# Parameter [Input]: testno
#   Test for which to run the simulation.
#
# Parameter [Input]: runfor
#   run-time of simulation
#
proc ::RTL_sim_lib::run_timed_simulation {testno limit} {
  variable is_aldec
  variable is_modelsim

  if {$is_aldec} {
    run $limit
    acdb save -file coverage/test_$testno.acdb
    endsim
  }
  if {$is_modelsim} {
    run $limit
    if {![file exists ./coverage]} {
      file mkdir ./coverage
    }
    coverage save coverage/test_$testno.ucdb
  }
}


#
# Brief:
#   Sets up and runs one or multiple tests.  All parameters are passed in using
#   a single params dictionary.  The individual parameter values listed below
#   are the dictionary keys used to pull out the values.
#
# Parameter [Input]: test_params
#   Dictionary of the tests run.
#
# Parameter [Input]: resolution_options (optional)
#   Simulation time resolution
#
# Parameter [Input]: wave_list (optional)
#   List of signals to log.
#
# Parameter [Input]: simulation_map (optional)
#   Dictionary that maps each test bench with a set of tests.
#
# Parameter [Input]: tb_entity (optional)
#   Name of the testbench for which to build the dependencies.
#
# Parameter [Input]: simulate_options (optional)
#   Dictionary on additional vsim commands per testbench entity.
#
# Details:
#   This procedure determines which tests to run for the current built and
#   compiled sources. Then for each test (unless a single one specified via
#   command line) it sets up the log file, initializes the simulation using
#   default options, passes the appropriate generics to the test bench, and
#   finally it runs the simulation.
#
# Usage:
#   RTL_sim_lib::run_tests $test_params $component1tb_map
#
proc ::RTL_sim_lib::run_tests {params} {
  variable sim_options
  variable tb_src_list
  
  set supported_resolution  {
                              fs 1fs 10fs 100fs
                              ps 1ps 10ps 100ps
                              ns 1ns 10ns 100ns
                              us 1us 10us 100us
                              ms 1ms 10ms 100ms
                              sec 1sec 10sec 100sec
                            }

  if {[info exists params] && [dict exists $params test_params]} {
    set test_params [dict get $params test_params]
  } else {
    error "RTLSIMLIB: Missing parameters to run_tests."
  }

  # Determine which test bench source should be used to run. If multiple
  # test benches exists, the user must specify one, unless it can be automatically
  # resolved.
  if {[info exists sim_options] && [dict exists $sim_options testbench]} {
    set tb_entity [dict get $sim_options testbench]
    puts "RTLSIMLIB: Setting test bench entity to $tb_entity"
  } elseif {[dict exists $params tb_entity]} {
    set tb_entity [dict get $params tb_entity]
    puts "RTLSIMLIB: Setting test bench entity to $tb_entity"
  } elseif {[llength $tb_src_list] > 1} {
    # If a single test is being requested and the simulation map exists, the
    # simulation map can be searched to determine the testbench to use
    if {[info exists sim_options] && [dict exists $sim_options testno] &&
        [dict exists $params simulation_map]} {
      # Requested test
      set testno [dict get $sim_options testno]
      # No key found yet
      set tb_entity_found 0
      # Loop through the simulation map and see if the test exists, and if more
      # than one TB calls that test
      dict for {testbenchName testNameList} [dict get $params simulation_map] {
        if {$testno in $testNameList} {
          # Key exists in more than one testbench, issue error
          if $tb_entity_found {
            error "RTLSIMLIB: Test exists across multiple testbenches. Please specify which testbench to run."
          }
          # Set testbench entity
          set tb_entity_found 1
          set tb_entity $testbenchName
          puts "RTLSIMLIB: Setting test bench entity to $tb_entity (automatically resolved)"
        }
      }
      if ![info exists tb_entity] {
        error "RTLSIMLIB: No testbench associated with the specified testno or the specified testno does not exist."
      }
    } else {
    error "RTLSIMLIB: Multiple test bench entities exist. Please specify which one to run."
    }
  } else {
    set tb_entity [lindex [file split $tb_src_list] end]
    puts "RTLSIMLIB: Setting test bench entity to $tb_entity"
  }

  # Set up the list of test benches. If multiple test benches exists, the user
  # should have defined a simulation map. If a single test bench exists then
  # set up a list of all test benches.
  if {[dict exists $params simulation_map] && [dict exists [dict get $params simulation_map] $tb_entity]} {
    set tb_entity_tests_list [dict get [dict get $params simulation_map] $tb_entity]
  } else {
    set tb_entity_tests_list [dict keys $test_params]
  }

  # Check function parameters for extra simulation options
  if {[dict exists $params simulate_options] && [dict exists [dict get $params simulate_options] $tb_entity]} {
    set tb_options [dict get [dict get $params simulate_options] $tb_entity]
  } else {
    set tb_options {}
  }

  # Run the tests for the chosen test bench.
  foreach testno $tb_entity_tests_list {
    set timestart [clock seconds]
    # Skip the tests we don't want to run.
    if {[info exists sim_options] && [dict exists $sim_options testno]} {
      if {[dict get $sim_options testno] != $testno} {
        continue
      }
    }
    
    # Check if a certain test case use custom simulation resolution
    # Default time resolution to ps
    set sim_resolution "ps"
    if {[dict exists $params resolution_options]} {
      set resolution_options [dict get $params resolution_options]
      if {[dict exists $resolution_options $testno]} {
        set sim_resolution [dict get $resolution_options $testno]
      }
      
      # Now validate sim_resolution
      if {[expr [lsearch $supported_resolution $sim_resolution] < 0]} {
        # Error if provided time resolution is not valid
        error "RTLSIMLIB: $sim_resolution is not a valid time resolution"
      }
    }

    puts "------------------------------"
    set parameters [dict get $test_params $testno]
    RTL_sim_lib::set_log "simulation_$testno"
    puts "RTLSIMLIB: Running test: $testno for $tb_entity."
    puts "RTLSIMLIB: Simulation resolution: $sim_resolution."
    puts "RTLSIMLIB:  Test options: $tb_options"
    puts "RTLSIMLIB:  Test parameters: $parameters"

    # Run pre-sim hooks here so it's counted in the timer
    # Some gen_data scripts are long, and this is a good metric to have.
    RTL_sim_lib::per_sim_cmd $testno $params 1

    RTL_sim_lib::initialize_simulation $testno $tb_entity $parameters $sim_resolution $tb_options

    if {[info exists sim_options] && [dict exists $sim_options loglist] && [dict exists $params wave_list]} {
      RTL_sim_lib::log_signal_wave [dict get $params wave_list]
    } else {
      RTL_sim_lib::log_signal_wave
    }
    if {[info exists sim_options] && [dict exists $sim_options runfor]} {
      set limit [dict get $sim_options runfor]
      RTL_sim_lib::run_timed_simulation $testno $limit
    } else {
      RTL_sim_lib::run_simulation $testno
    }

    #Run post-sim hooks if present, again, in the space of the timer
    RTL_sim_lib::per_sim_cmd $testno $params 0

    puts "RTLSIMLIB: Test $testno Complete - Elapsed Time [clock format \
      [expr {[clock seconds] - $timestart}] -format {%H:%M:%S} -timezone :UTC]\n\n"
  }

  # Warn the user if no tests were run
  if {![info exists parameters]} {
    error [concat "RTLSIMLIB: Test " [dict get $sim_options testno] "does not exist"]
  }
}


#
# Brief:
#   Sets up the list of signals to log.
#
# Parameter [Input]: wave_list (optional)
#   TCL list containing all the signals to add to the waveform viewer or log
#   to the waveform database. The default setting is to log "-port uut/*"
#
# Usage:
#   RTL_sim_lib::log_signal_wave $component_signals_list
#
# Remarks:
#   This procedure needs to be called independently for each item specified.
#   If the procedure is called without arguments, the list of signals is
#   specified via ::RTL_sim_lib::sim_options. If no options are specified, the
#   default is to only log the entity ports.
#
proc ::RTL_sim_lib::log_signal_wave {{wave_list {}}} {
  variable is_aldec
  variable is_aldec_vsimsa
  variable is_aldec_gui
  variable is_modelsim
  variable sim_options

  # Set the appropriate command. And run any other necessary commands.
  if {$is_aldec_vsimsa} {
    set log_wave_cmd "log"
  }
  if {$is_aldec_gui} {
    set log_wave_cmd "wave"
    eval $log_wave_cmd
  }
  if {$is_modelsim} {
    set log_wave_cmd "add wave"
  }

  # Log the provided signals.
  foreach signal $wave_list {
    puts "RTLSIMLIB: Logging $signal"
    eval $log_wave_cmd $signal
  }


  if {[info exists sim_options]} {
    # By default assume the UUT is named "uut", modify it if necessary.
    set instance_list uut
    if {[dict exists $sim_options logunits]} {
      set instance_list [dict get $sim_options logunits]
    }
    foreach instance_name $instance_list {
      if {[dict exists $sim_options logrecursive]} {
        puts "RTLSIMLIB: Logging recursively: -rec -var $instance_name/*"
        if {$is_aldec} {
          eval $log_wave_cmd "-rec -var $instance_name/*"
        } else {
          puts "INSTANCE NAME: $instance_name"
          eval $log_wave_cmd "-r $instance_name/*"
        }
      } elseif {[dict exists $sim_options loguuts]} {
        puts "RTLSIMLIB: Logging UUT ports: -ports $instance_name/*"
        if {$is_aldec} {
          eval $log_wave_cmd "-var $instance_name/*"
        } else {
          eval $log_wave_cmd "-depth 0 $instance_name/*"
        }
      } elseif {![dict exists $sim_options loglist]} {
        puts "RTLSIMLIB: Logging UUT ports: -ports $instance_name/*"
        # Issue a low-level warning if the instance_name isn't found while
        # trying to add the waves from it.
        set success [catch {eval $log_wave_cmd "-ports $instance_name/*"} msg]
        if {$success != 0} {
          puts "RTLSIMLIB: WARNING: command ($log_wave_cmd) failed: $msg"
        }
      }
    }
  }
}

#
# Brief:
#   Executes various user-specified scripts.
#
# Parameter [Input]:
#   Dictionary of the script commands to execute.
#   String identifier for message printing
#   String identifier for log file prefixes
#
# Usage:
#    RTL_sim_lib::exec_cmd_dictionary $command_dictionary
#
# Remarks:
#   This proc treats each value in the command_dictionary dictionary
#   as a command to execute, with the keys being irrelevant, as the
#   proc iterates through the entire dictionary.
#
proc ::RTL_sim_lib::exec_cmd_dictionary {command_dictionary msg_string log_string} {

  set script_num 1
  set logname_underscore _
  set logname_prefix $log_string$logname_underscore
  set logname_suffix ".log"

  if {[info exists command_dictionary]} {
    foreach item [dict keys $command_dictionary] {

      set logname $logname_prefix$script_num$logname_suffix
      # delete log file if it already exists
      if {[file exists $logname]} {
        file delete $logname
      }
      # Get the current command to execute
      set script_command [dict get $command_dictionary $item]

      # Execute the command, send both STD_ERR and STD_OUT to log file
      puts "RTLSIMLIB: Executing '$script_command'.\n"
      set success [catch {exec {*}$script_command >>& $logname }]

      # Print the log file to the console
      set fh [open $logname r]
      puts [read $fh]
      close $fh
      if {$success != 0} {
        error "Subroutine '$script_command' exited abnormally. See '$logname' for error details (shown above)."
      } else {
        puts "RTLSIMLIB: '$script_command' complete. See console and '$logname' for PASS/FAIL indication.\n\n"
      }
      incr script_num
    }
  } else {
    puts "RTLSIMLIB: No $msg_string script(s) specified"
  }
}

#
# Brief:
#   Generates coverage reports and prints a summary to stdout.
#
# Parameter [Input]: test_params
#   Dictionary of the tests run.
#
# Parameter [Input]: simulation_map
#   Dictionary that maps each test bench with a set of tests.
#
# Usage:
#   RTL_sim_lib::report_coverage $test_parameters
#
# Remarks:
#   This proc merges coverage from multiple tests and multiple test benches
#   into a single database. For that it relies on $simulation_map. The
#   dictionary entries must match the test bench entities for this command to
#   be successful. Coverage statistics are printed to stdout and recorded in
#   coverage.result to make statistics available to additional functions.
#
proc ::RTL_sim_lib::report_coverage {test_params {simulation_map {}}} {
  variable is_modelsim
  variable sim_options

  # If multiple test benches exists, then the acdb merge command requires some
  # replacements. Create a reverse lookup of the simulation map.
  if {[info exists simulation_map]} {
    dict for {tb_entity tests} $simulation_map {
      foreach test $tests {
        dict set reverse_simulation_map $test $tb_entity
      }
    }
  }

  # Clean up before generating reports.
  if {[file exists coverage.txt]} {
    file delete coverage.txt
  }

  if {[file exists coverage.html]} {
    file delete coverage.html
  }

  if {[file exists coverage_files]} {
    file delete -force coverage_files
  }

  # Set a default TB entity in case there are multiple.
  if {[info exists reverse_simulation_map]} {
    set default_tb [dict get $reverse_simulation_map 1]
  }

  if ($is_modelsim) {
    # Set the vcover merge command.
    set vcover_merge_cmd "vcover merge coverage/final.ucdb"
    dict for {testkey testValue} $test_params {
      append vcover_merge_cmd " coverage/test_${testkey}.ucdb"
    }

    eval $vcover_merge_cmd
    vcover report -details -html -htmldir coverage_files -code bces -verbose -source coverage/final.ucdb
    vcover report -details -code bces -file coverage.txt coverage/final.ucdb
    vcover report -details -zeros -code bces -file coverage_misses.txt coverage/final.ucdb
  } else {
    # Set the coverage merge command. Only replace the path for those tests that
    # need it. The replacement happens at the root level, and it only happens for
    # for the testbench entity name.
    set acdb_merge_cmd "acdb merge -o coverage/final.acdb"
    dict for {testkey testValue} $test_params {
      if {[info exists sim_options] && [dict exists $sim_options testno]} {
        if {[dict get $sim_options testno] != $testkey} {
          continue
        }
      }
      append acdb_merge_cmd " -i coverage/test_${testkey}.acdb"
      if {[info exists default_tb]} {
        set new_tb [dict get $reverse_simulation_map $testkey]
        if {$new_tb != $default_tb} {
          append acdb_merge_cmd " -rpath /$new_tb /$default_tb"
        }
      }
    }

    eval $acdb_merge_cmd
    acdb report -nohierarchy -db coverage/final.acdb -html -o coverage.html
    acdb report -nohierarchy -db coverage/final.acdb -txt -o coverage.txt
  }

  # Parse the coverage file and print the summary results.
  puts "RTLSIMLIB: Parsing Coverage Results:"
  if {[catch {set fh [open coverage.txt r]}]} {
    error "RTLSIMLIB: coverage.txt does not exists!"
  }
  # Read coverage.txt and parse for results.
  # Write coverage data to a temporary file (coverage.results) to allow follow-on
  # processes to view coverage data.
  set split_results [split [read -nonewline $fh] "\n"]
  close $fh
  set cov_results [open "coverage.results" "w"]
  if {$is_modelsim} {
    # Note these expressions are specific to ModelSim 10.6 and later.
    # Modelsim does not report a summary of coverage, but rather reports results
    # for each UUT entity independently.  The following loop will parse the
    # coverage report and sum all of the coverage statistics counting total
    # lines and covered lines.
    set stmts_tot 0
    set stmts_cov 0
    set branch_tot 0
    set branch_cov 0
    set cond_tot 0
    set cond_cov 0
    set expr_tot 0
    set expr_cov 0
    foreach line $split_results {
      if {[regexp -nocase {Stmts\s+\d+\s+\d+\s+\d+} $line]} {
        set parse_results [regexp -nocase -all -inline {\S+} $line]
        set stmts_tot [expr {$stmts_tot + [lindex $parse_results {1}]}]
        set stmts_cov [expr {$stmts_cov + [lindex $parse_results {2}]}]
      }
      if {[regexp -nocase {Branches\s+\d+\s+\d+\s+\d+} $line]} {
        set parse_results [regexp -nocase -all -inline {\S+} $line]
        set branch_tot [expr {$branch_tot + [lindex $parse_results {1}]}]
        set branch_cov [expr {$branch_cov + [lindex $parse_results {2}]}]
      }
      if {[regexp -nocase {FEC Condition Terms\s+\d+\s+\d+\s+\d+} $line]} {
        set parse_results [regexp -nocase -all -inline {\S+} $line]
        set cond_tot [expr {$cond_tot + [lindex $parse_results {3}]}]
        set cond_cov [expr {$cond_cov + [lindex $parse_results {4}]}]
      }
      if {[regexp -nocase {FEC Expression Terms\s+\d+\s+\d+\s+\d+} $line]} {
        set parse_results [regexp -nocase -all -inline {\S+} $line]
        set expr_tot [expr {$expr_tot + [lindex $parse_results {3}]}]
        set expr_cov [expr {$expr_cov + [lindex $parse_results {4}]}]
      }
    }
    #Report Coverage summary
    #Catch divide by 0 (meaning coverage type wasn't applicable)
    #and convert 0/0 to 100%
    if {$stmts_tot > 0}  {
      puts $cov_results [format "    %-23s %9d %9d %9d %9.2f" "Stmts" $stmts_tot $stmts_cov [expr {$stmts_tot - $stmts_cov}] [expr {100.0 * $stmts_cov / $stmts_tot}]]
    } else {
      puts $cov_results [format "    %-23s %9d %9d %9d %9.2f" "Stmts" $stmts_tot $stmts_cov [expr {$stmts_tot - $stmts_cov}] 100.0]
    }
    if {$branch_tot > 0} {
      puts $cov_results [format "    %-23s %9d %9d %9d %9.2f" "Branches" $branch_tot $branch_cov [expr {$branch_tot - $branch_cov}] [expr {100.0 * $branch_cov / $branch_tot}]]
    } else {
      puts $cov_results [format "    %-23s %9d %9d %9d %9.2f" "Branches" $branch_tot $branch_cov [expr {$branch_tot - $branch_cov}] 100.0]
    }
    if {$cond_tot > 0}   {
      puts $cov_results [format "    %-23s %9d %9d %9d %9.2f" "FEC Condition Terms" $cond_tot $cond_cov [expr {$cond_tot - $cond_cov}] [expr {100.0 * $cond_cov / $cond_tot}]]
    } else {
      puts $cov_results [format "    %-23s %9d %9d %9d %9.2f" "FEC Condition Terms" $cond_tot $cond_cov [expr {$cond_tot - $cond_cov}] 100.0]
    }
    if {$expr_tot > 0}  {
      puts $cov_results [format "    %-23s %9d %9d %9d %9.2f" "FEC Expression Terms" $expr_tot $expr_cov [expr {$expr_tot - $expr_cov}] [expr {100.0 * $expr_cov / $expr_tot}]]
    } else {
      puts $cov_results [format "    %-23s %9d %9d %9d %9.2f" "FEC Expression Terms" $expr_tot $expr_cov [expr {$expr_tot - $expr_cov}] 100.0]
    }
  } else {
    # Note these expressions are specific to Active-HDL 10.3 and later.
    set stmt_seen 0
    set brch_seen 0
    set expr_seen 0
    set cond_seen 0
    foreach line $split_results {
      if {[regexp -nocase -- {Statement Coverage} $line] && $stmt_seen == 0} {
        puts $cov_results "    $line"
        set stmt_seen 1
      }
      if {[regexp -nocase -- {Branch Coverage} $line] && $brch_seen == 0} {
        puts $cov_results "    $line"
        set brch_seen 1
      }
      if {[regexp -nocase -- {Expression Coverage} $line] && $expr_seen == 0} {
        puts $cov_results "    $line"
        set expr_seen 1
      }
      if {[regexp -nocase -- {Condition Coverage} $line] && $cond_seen == 0} {
        puts $cov_results "    $line"
        set cond_seen 1
      }
    }
    # If the key phrase wasn't found, assume it was a 0/0 case and output a message
    # of 100% for that type
    if {$stmt_seen == 0} {
      puts $cov_results "    | Statement Coverage  |      0 | 100.000% |"
    }
    if {$brch_seen == 0} {
      puts $cov_results "    | Branch Coverage     |      0 | 100.000% |"
    }
    if {$expr_seen == 0} {
      puts $cov_results "    | Expression Coverage |      0 | 100.000% |"
    }
    if {$cond_seen == 0} {
      puts $cov_results "    | Condition Coverage  |      0 | 100.000% |"
    }
  }
  #Close coverage results file to force data to be written out
  close $cov_results

  #Print coverage data to stdout
  set cov_results [open "coverage.results" "r"]
  puts [read $cov_results]
  close $cov_results
}


#
# Brief:
#   Deletes all files and directories passed in its argument.
#
# Parameter [Input]: trash_list
#   The list of files and directories to clean.
#
# Usage:
#   RTL_sim_lib::clean $trash_list
#
# Remarks:
#   Use carefully. It won't ask twice before running!
#
proc ::RTL_sim_lib::clean {trash_list} {
  variable is_aldec
  variable is_clearcase

  catch {eval file delete -force -- $trash_list}
  puts "RTLSIMLIB: files removed:"
  foreach item $trash_list {
    puts "  $item"
  }
  # Clean up the working library when using Aldec due to the fact that
  # RTL_sim_lib moves this folder to your local temp folder and it probalby won't
  # get cleaned up any other way.
  if {$is_aldec && $is_clearcase} {
    # The Aldec tool does not like having its working folder located in
    # clearcase ux dynamic views.  To avoid this situation we move the working
    # library to your systems temporary folder.  The following code to create
    # a temporary folder was copied from http://wiki.tcl.tk/772
    if {[file exists "/tmp"]} {set temp_folder "/tmp"}
    catch {set temp_folder $::env(TRASH_FOLDER)}
    catch {set temp_folder $::env(TMP)}
    catch {set temp_folder $::env(TEMP)}
    append temp_folder [join [list "/RTLMake/"] ""]
    if {[file exists $temp_folder]} {
      puts "RTLSIMLIB: Removing RTLMake Temporary folder: $temp_folder"
      file delete -force $temp_folder
    }
  }
}


#
# Brief:
#   List the directory's files recursively.
#
# Parameter [Input]: start_dir
#   Root of the tree to traverse for files.
#
# Parameter [Input]: ls_mode (optional)
#   Two modes of traversing the tree are provided
#     depth   - Depth-first mode (default).
#     breadth - Breadth-first mode.
#
# Returns:
#   The list of files ordered in $ls_mode.
#
# Usage:
#   RTL_sim_lib::ls_recurse .. depth
#
proc ::RTL_sim_lib::ls_recurse {start_dir {ls_mode depth}} {
  set file_ls [glob -nocomplain -type f -- $start_dir/*]
  if {$ls_mode == "depth"} {
    foreach dir [glob -nocomplain -type d -- $start_dir/*] {
      lappend file_ls $dir
      lappend file_ls {*}[RTL_sim_lib::ls_recurse $dir depth]
      lappend file_ls {*}[glob -nocomplain -type f -- $dir/*]
    }
  } elseif {$ls_mode == "breadth"} {
    foreach dir [glob -nocomplain -type d -- $start_dir/*] {
      lappend nfile $dir
      lappend nfile {*}[glob -nocomplain -type f -- $dir/*]
      lappend nfile {*}[RTL_sim_lib::ls_recurse $dir breadth]
    }
  } else {
    error "RTLSIMLIB: Unknown ls method."
  }
  return $file_ls
}


#
# Brief:
#   Subtract the items in original_list from the ones in new_list.
#
# Parameter [Input]: new_list
#   List from which to subtract (minuend).
#
# Parameter [Input]: old_list
#   List to subtract (subtrahend).
#
# Returns:
#   The list of files from $new_list that are not found in $original_list.
#
# Usage:
#   RTL_sim_lib::ls_recurse $new_list $original_list
#
proc ::RTL_sim_lib::lsubtract {new_list original_list} {
  set ldiff {}
  foreach item $new_list {
    if {[lsearch $original_list $item] < 0} {
      lappend ldiff $item
    }
  }
  return $ldiff
}

#
# Brief:
#   Update the garbage tracking dictionary.
#
# Parameter [Input]: tracker
#   Dictionary to track the contents of a directory. The dictionary must have
#   two entries:
#     contents  - Lists the contents of the directory being tracked.
#     garbage   - Lists the files and directories that are considered garbage.
#
# Returns:
#   An updated copy of $tracker.
#
# Usage:
#   RTL_sim_lib::ls_recurse $new_list $original_list
#
# Remarks:
#   Note. This procedure does not update $tracker. It returns an updated
#   version. Unfortunately, this is a necessary evil since we are not assuming
#   how this proc is called. Also, I couldn't make upvar work!
#
proc ::RTL_sim_lib::update_garbage {tracker} {
  set old_contents [dict get $tracker contents]
  # Update the contents in the tracker.
  set new_contents [RTL_sim_lib::ls_recurse ..]
  dict set tracker contents $new_contents
  foreach item [RTL_sim_lib::lsubtract $new_contents $old_contents] {
    if {[lsearch [dict get $tracker garbage] $item] < 0} {
      dict lappend tracker garbage $item
    }
  }
  return $tracker
}

# Register the package.
# Versioning:
#   I have not come up with any numbering rules, however, I have convinced
#   myself that numbering after the COMPONENTS_RTL label is not practical. A
#   good guideline would be to increase the minor version when enhancements are
#   introduced or when changes affecting functionality are made. The major
#   version could be increase if changes make the new version incompatible with
#   older ones, or if we deploy something big or fancy, like a GUI.
package provide RTL_sim_lib 1.1

#-------------------------------------------------------------------------------
# @copyright
# Copyright (c) 2019 Schweitzer Engineering Laboratories, Inc.
# SEL Confidential
#
#-------------------------------------------------------------------------------
puts ""
puts "Dynamic test_parameters.tcl is starting..."

dict set wave_lists all { "-rec *" }
dict set after_all_commands pass_fail { py -m pysim -vsj }

# Variable initializations
set test_parameters [dict create]
set after_sim_commands [dict create]
set before_sim_commands [dict create]

# Get a list of directories that start with a number,
# then two chars, underscore, and whatever else goes in the name.
set testdir_list [glob \[0-9\]*_*]

foreach testdir $testdir_list {

  puts [concat ">> Building test_parameters for: " $testdir]

  # 1) Set before_sim_command if gen_data.py is detected
  if {[file exists $testdir/gen_data.py]} {
    set gen_data_name "/gen_data.py"
    dict set before_sim_commands $testdir [concat "py -3 " $testdir$gen_data_name $testdir]
  }

  # 2) Build the test_parameters entry based on sim_params.txt
  if {[file exists $testdir/sim_params.txt]} {
    # Read sim_params.txt, it should look like a bunch of lines that go:
    # GENERIC_NAME   value
    set fid [open $testdir/sim_params.txt r]
    set params [read $fid]
    close $fid
    # Break the file into lines
    set param_pairs [split $params "\n"]
    # Initialize the testno and prepopulate "FILE_PREFIX" generic with the testdir name
    dict set test_parameters $testdir [dict create TEST_PREFIX $testdir]
    # Process each key/value pair
    foreach pair $param_pairs {
      # Skip blank lines (CRLF or similar)
      if {[string length $pair] > 2} {
        # Unpack (lassign) the tuple-like (key, value) thing into two named vars
        lassign [regexp -inline -all -- {\S+} $pair] \
            generic_name generic_value
        dict set test_parameters $testdir $generic_name $generic_value
      }
    }
  } else {
    # The test folder didn't have a sim_params.txt. The gen_data and verify are optional, but this is mandatory
    throw {FILE NOTFOUND {Must have sim_params.txt in the testdir listed above}} {Must have sim_params.txt in the testdir listed above}
  }
}

# Finished successfully
puts "Done running test_parameters.tcl"
puts ""

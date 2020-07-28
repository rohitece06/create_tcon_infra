# Copyright (c) 2016 Schweitzer Engineering Laboratories, Inc.
# SEL Confidential
#
# Notes:
#   Define the test parameters and simulation map for this component.
#   To use this file call it from another TCL script as follows:
#     source test_parameters.tcl
#

# Define generics dictionary.

dict set after_all_commands pass_fail { py -m pysim -v -s -j . }

dict set test_parameters 1 \
{
}

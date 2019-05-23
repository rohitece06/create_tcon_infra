# Copyright (c) 2015 Schweitzer Engineering Laboratories, Inc.
# SEL Confidential
#
# Notes:
#   Define the test parameters and simulation map for this component.
#   To use this file call it from another TCL script as follows:
#     source test_parameters.tcl
#

# Define generics dictionary.
dict set test_parameters 1 \
{
  SAIF_BASE_FILENAME "saif_32"
  D_WIDTH_STIM       32
  D_WIDTH_UUT        32
  STAGE_TYPE         1
}

dict set test_parameters 2 \
{
  SAIF_BASE_FILENAME "saif_32"
  D_WIDTH_STIM       32
  D_WIDTH_UUT        1
  STAGE_TYPE         1
}

dict set test_parameters 3 \
{
  SAIF_BASE_FILENAME "saif_32"
  D_WIDTH_STIM       32
  D_WIDTH_UUT        1200
  STAGE_TYPE         1
}

dict set test_parameters 4 \
{
  SAIF_BASE_FILENAME "saif_32_no_pipe"
  D_WIDTH_STIM       32
  D_WIDTH_UUT        1200
  STAGE_TYPE         0
}

dict set after_all_commands pass_fail { py -m pysim -v -s -j . }
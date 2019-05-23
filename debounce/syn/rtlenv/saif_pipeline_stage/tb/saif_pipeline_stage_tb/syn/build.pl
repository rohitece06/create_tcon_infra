#
# Copyright (c) 2014 Schweitzer Engineering Laboratories, Inc.
# SEL Confidential
#
# @file build.pl
#
# @brief This file is used to generate all dependent sources for this component.
#
# @remarks
# * This file is used by the {ClearCase}\tools\bin\build_rtl.pl script
# * Documentation of build_rtl script can be found at:
#      {ClearCase}\tools\doc\build_rtl_users_guide.doc
#

$VARS =
{
  VHD_SOURCE_LIST_TCL_FILE  => "$MYDIR../../../sim/vhd_source_list.tcl",
};

$SOURCES =
[
  "$MYDIR../src/saif_pipeline_stage_tb.vhd",
];

$COMPONENTS =
[
  "$MYDIR../../..",
  "$MYDIR../../../../tb/saif_master",
  "$MYDIR../../../../tb/saif_slave",
  "$MYDIR../../../../tb/print_fnc",
];

# Dynamically generated temp files are defined in the following
#  array reference of hashes
# Each hash represents one temp file. It is defined by multiple
#  key/value pairs. The first one, NAME, defines the name and
#  path of where the temp file is to be generated.
# You define the text to include in a value associated with a
#  TEXT key.  This is also a great place to utilize project variables.
# Usually one of these files needs to contain a list of component
#  sources. This is accomplished by using the following syntax
#              <<< some prefix SOURCES some postfix >>>
#
# For example, assume a component has two source files called
#  source1.vhd and source2.vhd. The use of the tag detailed above
#  would yield the following listing in you text file:
#
# some prefix source1.vhd some postfix
# some prefix source2.vhd some postfix
$TEMPFILES =
[
   {
      NAME  => $VARS->{VHD_SOURCE_LIST_TCL_FILE},
      TEXT  =>
         "#-------------------------------------------------------------------------\n" .
         "# \@copyright\n"                                                              .
         "# Copyright (c) 2014 Schweitzer Engineering Laboratories, Inc.\n"             .
         "# SEL Confidential\n"                                                         .
         "#\n"                                                                          .
         "# \@file $VARS->{VHD_SOURCE_LIST_TCL_FILE}\n"                                 .
         "#\n"                                                                          .
         "# \@brief\n"                                                                  .
         "#  This dynamically created TCL script can be included by\n"                  .
         "#   other TCL scripts to recover the project source list for\n"               .
         "#   compilation purposes.\n"                                                  .
         "#\n"                                                                          .
         "# \@remarks\n"                                                                .
         "#  Use the following syntax within TCL scripts to recover the\n"              .
         "#  sources:\n"                                                                .
         "#   source $VARS->{VHD_SOURCE_LIST_TCL_FILE}\n"                               .
         "#-------------------------------------------------------------------------\n" .
         "\n"                                                                           .
         "set src_list \\\n"                                                             .
         "{\n"                                                                          .
         "<<<  SOURCES>>>"                                                              .
         "}\n"
   },
];


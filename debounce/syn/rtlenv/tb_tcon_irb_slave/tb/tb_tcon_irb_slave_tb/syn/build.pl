# Copyright (c) 2019 Schweitzer Engineering Laboratories, Inc.
# SEL Confidential
# See /tools/doc/build_rtl_users_guide.doc for build system documentation.

$VARS =
{
  VHD_SOURCE_LIST_TCL_FILE  => "$MYDIR../../../sim/vhd_source_list.tcl",
};

$SOURCES =
[
  "$MYDIR../src/tb_tcon_irb_slave_tb.vhd"
];

$COMPONENTS =
[
  "tb_tcon_irb_slave",
  "components/rtl/tb/tb_tcon; SHARED_LIB=>scripted-component",
  "tb_tcon_clocker",
  "tb_tcon_irb_master",
];

$TEMPFILES =
[
   {
      NAME  => $VARS->{VHD_SOURCE_LIST_TCL_FILE},
      TEXT  =>
         "#-------------------------------------------------------------------------\n" .
         "# Copyright (c) 2016 Schweitzer Engineering Laboratories, Inc.\n"             .
         "# SEL Confidential\n"                                                         .
         "#\n"                                                                          .
         "#  This dynamically created TCL script can be included by\n"                  .
         "#   other TCL scripts to recover the project source list for\n"               .
         "#   compilation purposes.\n"                                                  .
         "#\n"                                                                          .
         "#  Use the following syntax within TCL scripts to recover the\n"              .
         "#  sources:\n"                                                                .
         "#   source $VARS->{VHD_SOURCE_LIST_TCL_FILE}\n"                               .
         "#-------------------------------------------------------------------------\n" .
         "\n"                                                                           .
         "set src_list \\\n"                                                            .
         "{\n"                                                                          .
         "<<<  SOURCES>>>"                                                              .
         "}\n"
   },
];
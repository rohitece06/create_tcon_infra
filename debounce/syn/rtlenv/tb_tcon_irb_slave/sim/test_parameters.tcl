#-------------------------------------------------------------------------------
# Copyright (c) 2019 Schweitzer Engineering Laboratories, Inc.
# SEL Confidential
#-------------------------------------------------------------------------------

dict set after_all_commands pass_fail {py -3 -m pysim -v -s -j . }

RTL_sim_lib::auto_discover_tests
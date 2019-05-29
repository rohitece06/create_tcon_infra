from datetime import datetime


START_PAREN = "("
END_PAREN = ")"
# Every VHDL block type that defines a component entirely
VHDL_BLOCK = {"type": ["entity", "component", "package"],
              "start_token": "is",
              "end_token": "end"}

# VHDL interface types
VHDL_IF = {"type": ["generic", "port"],
           "start_token": START_PAREN,
           "end_token": ");"}

# BLocks inside VHDL "architecture": Declaration (_DECL) and Definition (_DEF)
#   * Declaration contains signal, function, alias declaration inside the
#     architecture
VHDL_ARCH = {"type": ["architecture"],
             "start_token": "is",
             "end_token": "end"}
VHDL_ARCH_DEF = {"type": ["architecture definition"],
                 "start_token": "begin",
                 "end_token": "end"}
VHDL_PROC = {"type": ["process", "block"],
             "start_token": "begin",
             "end_token": "end"}

VHDL_CONSTRUCT_TYPES = [VHDL_BLOCK, VHDL_IF, VHDL_ARCH, VHDL_PROC]

# VHDL Port direction types
VHDL_DIR_TYPE = ["in", "out", "inout"]
# Instant assignment operator
INST_ASSIGN_OP = ":="
# Signal assignment operator
SIG_ASSIGN_OP = "<="


# Use default BUS configurations if user did not provide one
DEFAULT_TCON_TBS =  {"CLK"   : "tb_tcon_clocker",
                     "MISC"   : None,
                     "IRBM"  : "tb_tcon_irb_slave",
                     "IRBS"  : "tb_tcon_irb_master",
                     "SAIFM" : "tb_tcon_saif",
                     "SAIFS" : "tb_tcon_saif",
                     "SDM"   : "tb_tcon_start_done_slave",
                     "SDS"   : "tb_tcon_start_done"}

# Location where all tb components are (must use rtlenv to pull all dependencies
# before running this script)
TB_SRC_LOCATION = "./syn/rtlenv/"

BUS_CFG_FILE = "BUS_CONFIG.cfg"


TB_HEADER ="""
--------------------------------------------------------------------------------
-- COPYRIGHT (c) {} Schweitzer Engineering Laboratories, Inc.
-- SEL Confidential
--
-- Description: {}_tb, testbench of the {} component
--
-- NR = Not Registered
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
"""

TB_ENTITY = """
entity {}_tb is
    generic
    (

    );
end {}_tb;

architecture sim of {}_tb is
  -- Number of clocks
  constant NUM_CLOCKS : integer := 1;

{}

begin

{}

end sim;
"""


INIT_HEADER = """
# Copyright (c) {}, Schweitzer Engineering Laboratories, Inc.
# SEL Confidential
"""

INIT_ENTRY = """
from .common import *
"""

TB_COMP_MAP_WITH_GENERICS = """
  -- {} instantiation
  {} : entity work.{}
  generic map  (
    {}
  )
  port map
  (
    {}
  );
"""
TB_COMP_MAP_WO_GENERICS = """
  {} : entity work.{}
  port map  (
    {}
  );
"""
# Generic map entries are formed as
#       <name> => <value>,
GENERIC_MAP_ENTRY = "{} => {}, \n"
# Last entry do not have comma
GENERIC_MAP_LAST_ENTRY = "{} => {} \n"

# Port map entries are formed as
#       <name> => <value>, -- <direction>
# The comma should be removed for last entry
PORT_MAP_ENTRY  = "{} => {}, -- {}\n"
# Last entry do not have comma before comment
PORT_MAP_LAST_ENTRY  = "{} => {} -- {}\n"

# Signal declaration entries are formed as
#   signal name <variable number of spaces>: <type>;
SIGNAL_ENTRY = "  signal {}: {};"
SIGNAL_ENTRY_WITH_DEFAULT = "  signal {}: {} {};"
# Generic declaration in an entity is formed as
#   <name> : value;
GENERIC_ENTRY = "    {} {}: {};"
GENERIC_LAST_ENTRY = "    {} {}: {}"

# Similar names that typically represent the same idea
NAMES_DWIDTH = ["DWIDTH", "DATA_DWIDTH", "D_WIDTH"]
NAMES_AWIDTH = ["AWIDTH", "ADDR_WIDTH", "A_WIDTH"]
NAMES_BASE   = ["BASE", "BASE_ADDR"]

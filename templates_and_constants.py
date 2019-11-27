from collections import OrderedDict

START_PAREN = "("
END_PAREN = ")"
# Every VHDL block type that defines a component entirely
VHDL_BLOCK = {"type": ["entity", "component", "package"],
              "start_token": "is",
              "end_token": "end"}

# VHDL interface types
VHDL_IF = {"type": ["generic", "port"],
           "start_token": START_PAREN,
           "end_token": END_PAREN+";"}

# BLocks inside VHDL "architecture": Declaration (_DECL) and Definition (_DEF)
#   * Declaration contains signal, function, alias declaration inside the
#     architecture
VHDL_ARCH = {"type": ["architecture"],
             "start_token": "is",
             "end_token": None}

VHDL_ARCH_DEF = {"type": ["arch definition"],
                 "start_token": "begin",
                 "end_token": "end",
                 "false_start_token": ["begin"]}

VHDL_PROC = {"type": ["process", "block"],
             "start_token": "begin",
             "end_token": "end"}

VHDL_COMP_GEN_MAP = {"type": ["generic map"],
                     "start_token": "generic map",
                     "end_token": " )",
                     "false_start_token": "("}

VHDL_CONSTRUCT_TYPES = [VHDL_BLOCK, VHDL_IF, VHDL_ARCH, VHDL_PROC,
                        VHDL_COMP_GEN_MAP]

# VHDL Port direction types
VHDL_DIR_TYPE = ["in", "out", "inout"]
# Instant assignment operator
INST_ASSIGN_OP = ":="
# Signal assignment operator
SIG_ASSIGN_OP = "<="

# Use default BUS configurations if user did not provide one
DEFAULT_TCON_TBS = {"CLK": "tb_tcon_clocker",
                    "MISC": None,
                    "IRBM": "tb_tcon_irb_slave",
                    "IRBS": "tb_tcon_irb_master",
                    "SAIFM": "tb_tcon_saif",
                    "SAIFS": "tb_tcon_saif",
                    "SDM": "tb_tcon_start_done_slave",
                    "SDS": "tb_tcon_start_done"}

SUPPORTED_BUSSES = list(set(DEFAULT_TCON_TBS.keys()) - set(["CLK", "MISC"]))

# Location where all tb components are (must use rtlenv to pull all dependencies
# before running this script)
TB_SRC_LOCATION = "./syn/rtlenv/"

BUS_CFG_FILE = "BUS_CONFIG.cfg"


TB_HEADER = """
-------------------------------------------------------------------------------
-- COPYRIGHT (c) {} Schweitzer Engineering Laboratories, Inc.
-- SEL Confidential
--
-- Description: {}_tb, testbench of the {} component
--
-- NR = Not Registered
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
"""

TB_ENTITY = """
entity {}_tb is
  generic (
{}
  );
end {}_tb;
"""

TB_BODY = """
architecture sim of {}_tb is

  ------------
  -- Constants
{}
  ----------
  -- Signals
  signal tb_reset : std_logic;

{}
begin
{}

end sim;
"""

INIT_PY = """
# Copyright (c) {}, Schweitzer Engineering Laboratories, Inc.
# SEL Confidential
from .common import *
"""

TB_DEP_MAP_WITH_GENERICS = """
  {}
  -- {} instance
  {} : entity work.{}
  generic map  (
{}
  )
  port map
  (
{}
  );
"""
TB_DEP_MAP_WO_GENERICS = """
  {}
  -- {} instance
  {} : entity work.{}
  port map  (
{}
  );
"""

TB_ARCH_FILL = " " * 2
TB_ENTITY_FILL = " " * 4
TB_DEP_FILL = " " * 4

# Similar names that typically represent the same idea
MATCH_DWIDTH = ["DWIDTH", "DATA_WIDTH", "D_WIDTH"]
MATCH_AWIDTH = ["AWIDTH", "ADDR_WIDTH", "A_WIDTH"]
MATCH_BASE = ["BASE", "BASE_ADDR"]
MATCH_WR = ["wr", "write"]
MATCH_RD = ["rd", "read"]
MATCH_ADDR = ["addr", "address"]
MATCH_RST = ["reset", "rst"]
MATCH_CLK = ["clk", "clock"]
MATCH_LOG_FILE = ["LOG", "LOG_FILE", "LOGFILE"]
MATCH_DI = ["din", "data_in", "di", "data"]
MATCH_DO = ["dout", "data_out", "do", "data"]
MATCH_DATA = MATCH_DI + MATCH_DO
MATCH_CMD_FILE = ["CMD_FILE", "COMMAND_FILE"]
MATCH_IGNORE_GENERICS = ["FLOP_DELAY", "FLOPDELAY"]
# VECTOR_TYPES =

# If UUT is a SAIF slave, then tb's rtr connects to UUT's cts, ctr to rts, etc
SAIFM_MAP = OrderedDict({"rtr": ["cts"], "ctr": ["rts"], "data": MATCH_DO,
                         "eof": ["eof"], "df": ["df"], "sof": ["sof"]})
# If UUT is a SAIF slace, then tb's rts connects to UUT's ctr, cts to rtr, etc
SAIFS_MAP = OrderedDict({"rts": ["ctr"], "cts": ["rtr"], "data": MATCH_DI,
                         "eof": ["eof"], "df": ["df"], "sof": ["sof"]})
IRB_MAP = OrderedDict({"wr": MATCH_WR, "rd": MATCH_RD, "ack": "ack",
                       "busy": "busy", "addr": MATCH_ADDR, "di": MATCH_DO,
                       "do": MATCH_DI})
SD_MAP  = OrderedDict({"start": ["start"], "done": ["done"],
                       "data": MATCH_DATA, "din": MATCH_DO, "dout": MATCH_DI})

TB_MAP_KEYS = OrderedDict({"CLK": MATCH_CLK,
                           "IRBM": IRB_MAP.keys(),
                           "IRBS": IRB_MAP.keys(),
                           "SAIFM": SAIFS_MAP.keys(),
                           "SAIFS": SAIFM_MAP.keys(),
                           "SDM": SD_MAP.keys(),
                           "SDS": SD_MAP.keys()})

TB_MAP = OrderedDict({"CLK": MATCH_CLK,
                      "IRBM": IRB_MAP,
                      "IRBS": IRB_MAP,
                      "SAIFM": SAIFM_MAP,
                      "SAIFS": SAIFS_MAP,
                      "SDM": SD_MAP,
                      "SDS": SD_MAP})
KEYWORDS = ["variable", "signal", "constant", "natural", "boolean",
            "std_logic", "std_logic_vector", "unsigned", "array_slv",
            "array_slv3d", "string", "positive", "integer", "process",
            "port map"]

# Template to create QSF assignments for top level generics
QSF_GENERIC_ASSIN = "set_parameter -name {} {}"
